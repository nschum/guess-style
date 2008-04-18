;;; guess-style.el --- automatic setting of code style variables
;;
;; Copyright (C) 2009 Nikolaj Schumacher
;;
;; Author: Nikolaj Schumacher <bugs * nschum de>
;; Version: 
;; Keywords: c, files, languages
;; URL: http://nschum.de/src/emacs/guess-style/
;; Compatibility: GNU Emacs 22.x, GNU Emacs 23.x
;;
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;;; Change Log:
;;
;;    Initial release.
;;
;;; Code:

(eval-when-compile (require 'cl))

(defgroup guess-style nil
  "Automatic setting of code style variables."
  :group 'c
  :group 'files
  :group 'languages)

(defcustom guess-style-override-file "~/.guess-style"
  "*File name for storing the manual style settings"
  :group 'guess-style
  :type 'file)

(defvar guess-style-guesser-alist
  '((indent-tabs-mode . guess-style-guess-tabs-mode)
    (tab-width . guess-style-guess-tab-width)
    (c-basic-offset . guess-style-guess-c-basic-offset))
  "A list of cons containing a variable and a guesser function.")

;;;###autoload
(defun guess-style-set-variable (variable value)
  "Change VARIABLE's guessed value.
To remember the guess for the future, use `guess-style-override-variable'."
  (interactive (list (intern (completing-read "Variable: "
                                              guess-style-guesser-alist nil t))
                     (read (read-string "Value: "))))
  (set (make-local-variable variable) value))

(defvar guess-style-overridden-variable-alist nil
  "List of files and directories with manually overridden guess-style variables.
It is sorted, use only `guess-style-override-variable' to modify this variable")

(defun guess-style-overridden-variables (&optional file)
  "Return a list of FILE's overridden variables and their designated values.
If FILE is nil, `buffer-file-name' is used."
  (setq file (abbreviate-file-name (or file buffer-file-name)))
  (unless (get 'guess-style-overridden-variable-alist 'read-from-file)
    (guess-style-read-override-file))
  (let ((alist guess-style-overridden-variable-alist)
        result)
    (while alist
      (if (equal (substring file 0 (min (length (caar alist)) (length file)))
                 (caar alist))
          (setq result (cdar alist)
                alist nil)
        (pop alist)))
    result))

(if (boundp 'recentf-dump-variable)
    (defalias 'guess-style-dump-variable 'recentf-dump-variable)
  (defun guess-style-dump-variable (variable &optional limit)
    (let ((value (symbol-value variable)))
      (if (atom value)
          (insert (format "\n(setq %S '%S)\n" variable value))
        (when (and (integerp limit) (> limit 0))
          (setq value (recentf-trunc-list value limit)))
        (insert (format "\n(setq %S\n      '(" variable))
        (dolist (e value)
          (insert (format "\n        %S" e)))
        (insert "\n        ))\n")))))

(defun guess-style-write-override-file ()
  "Write overridden variables to `guess-style-override-file'."
  ;; based on recentf-save-list
  (condition-case error
      (with-temp-buffer
        (erase-buffer)
        (set-buffer-file-coding-system 'emacs-mule)
        (insert (format ";;; Generated by `guess-style' on %s"
                        (current-time-string)))
        (guess-style-dump-variable 'guess-style-overridden-variable-alist)
        (insert "\n\n;;; Local Variables:\n"
                (format ";;; coding: %s\n" 'emacs-mule)
                ";;; End:\n")
        (write-file (expand-file-name guess-style-override-file)))
    (error
     (warn "guess-style: %s" (error-message-string error)))))

(defun guess-style-read-override-file ()
  "Read overridden variables from `guess-style-override-file'."
  (let ((file (expand-file-name guess-style-override-file)))
    (if (file-readable-p file)
        (load-file file)
      (warn "guess-style override file %s not found" guess-style-override-file))
    (put 'guess-style-overridden-variable-alist 'read-from-file t)))

(defun guess-style-override-variable (variable value file)
  "Override VARIABLE's guessed value for future guesses.
If FILE is a directory, the variable will be overridden for the entire
directory, unless single files are later overridden.
If called interactively, the current buffer's file name will be used for FILE.
With a prefix argument a directory name may be entered.
To change a variable for the current session only, use
`guess-style-set-variable'."
  (interactive (list (intern (completing-read "Variable: "
                                              guess-style-guesser-alist nil t))
                     (read (read-string "Value: "))
                     (if current-prefix-arg
                         (read-file-name "Directory: " nil
                                         (file-name-directory buffer-file-name))
                       buffer-file-name)))
  ;; abbreviate file name for portability (e.g. different home directories)
  (setq file (abbreviate-file-name file))
  (if (file-directory-p file)
      (setq file (file-name-as-directory file))
    (setq file (directory-file-name file)))
  (guess-style-set-variable variable value)
  (unless (get 'guess-style-overridden-variable-alist 'read-from-file)
    (guess-style-read-override-file))
  (let ((match (assoc file guess-style-overridden-variable-alist)))
    (if match
        (let ((pair (assq variable (cdr match))))
          (if pair
              ;; replace
              (setcdr pair value)
            ;; append
            (setcdr match (cons (cons variable value) (cdr match)))))
      ;; insert
      (push (list file (cons variable value))
            guess-style-overridden-variable-alist)
      ;; keep list sorted
      ;; TODO: just the new element is out of order, bubble it up
      (setq guess-style-overridden-variable-alist
            (sort guess-style-overridden-variable-alist
                  (lambda (a b) (not (string< (car a) (car b))))))))
  (guess-style-write-override-file))

;;;###autoload
(defun guess-style-guess-variable (variable &optional guesser)
  "Guess a value for VARIABLE according to `guess-style-guesser-alist'.
If GUESSER is set, it's used instead of the default."
  (unless guesser
    (setq guesser (cdr (assoc variable guess-style-guesser-alist))))
  (condition-case err
      (let ((overridden-value
             (cdr (assoc variable (guess-style-overridden-variables)))))
        (guess-style-set-variable variable (or overridden-value
                                               (funcall guesser)))
        (message "%s variable '%s' (%s)"
                 (if overridden-value "Remembered" "Guessed")
                 variable (eval variable)))
    (error (message "Could not guess variable '%s' (%s)" variable
                    (error-message-string err)))))

;;;###autoload
(defun guess-style-guess-all ()
  "Guess all variables in `guess-style-guesser-alist'."
  (interactive)
  (dolist (pair guess-style-guesser-alist)
    (guess-style-guess-variable (car pair) (cdr pair))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun guess-style-error (&rest args)
  "Signal an error like `error', but don't debug it."
  (let ((debug-ignored-errors `(,(apply 'format args))))
    (error (car debug-ignored-errors))))

(defcustom guess-style-maximum-false-spaces 0.3
  "*The percentage of space indents with five or more to keep `tab-width' at 4."
  :type 'number
  :group 'guess-style)

(defcustom guess-style-minimum-line-count 3
  "*The number of significant lines needed to make a guess."
  :type 'number
  :group 'guess-style)

(defcustom guess-style-too-close-to-call .05
  "*Certainty Threshold under which no decision will be made."
  :type 'number
  :group 'guess-style)

(defcustom guess-style-maximum-false-tabs 0.3
  "*The percentage of tab lines allowed to keep `indent-tabs-mode' nil."
  :type 'number
  :group 'guess-style)

(defun guess-style-guess-tabs-mode ()
  "Guess whether tabs are used for indenting in the current buffer."
  (save-restriction
    (widen)
    (let* ((num-tabs (how-many "^\t" (point-min) (point-max)))
           (num-nontabs (how-many "^    " (point-min) (point-max)))
           (total (+ num-tabs num-nontabs)))
      (when (< total guess-style-minimum-line-count)
        (guess-style-error "Not enough lines"))
      (> (/ (float num-tabs) total) guess-style-maximum-false-tabs))))

(defun guess-style-guess-tab-width ()
  "Guess whether \\t in the current buffer is supposed to mean 4 or 8 spaces."
  (save-restriction
    (widen)
    (let ((many-spaces (how-many "^\t+ \\{4,7\\}[^ ]" (point-min) (point-max)))
          (few-spaces (how-many "^\t+  ? ?[^ ]" (point-min) (point-max))))
      (when (< (+ many-spaces few-spaces) guess-style-minimum-line-count)
        (guess-style-error "Not enough lines"))
      (if (> many-spaces
             (* guess-style-maximum-false-spaces few-spaces)) 8 4))))

(defun guess-style-how-many (regexp)
  "A simplified `how-many' that uses `c-syntactic-re-search-forward'."
  (save-excursion
    (goto-char (point-min))
    (let ((count 0) opoint)
      (while (and (< (point) (point-max))
                  (progn (setq opoint (point))
                         (c-syntactic-re-search-forward regexp nil t)))
        (if (= opoint (point))
            (forward-char 1)
          (setq count (1+ count))))
      count)))

(defun guess-style-guess-c-basic-offset ()
  (unless (and (boundp 'c-buffer-is-cc-mode) c-buffer-is-cc-mode)
    (guess-style-error "Not a cc-mode"))
  (let* ((tab (case tab-width
                (8 "\\(\\( \\{,7\\}\t\\)\\|        \\)")
                (4 "\\(\\( \\{,3\\}\t\\)\\|    \\)")
                (2 "\\(\\( ?\t\\)\\|  \\)")))
         (end "[^[:space:]]")
         (two-exp (case tab-width
                    (8 (concat "^" tab "*   \\{4\\}?" end))
                    (4 (concat "^" tab "*  " end))
                    (2 (concat "^" tab tab "\\{2\\}*" end))))
         (four-exp (case tab-width
                     (8 (concat "^" tab "* \\{4\\}" end))
                     (4 (concat "^" tab tab "\\{2\\}*" end))
                     (2 (concat "^" tab "\\{2\\}" tab "\\{4\\}*" end))))
         (eight-exp (case tab-width
                      (8 (concat "^" tab "+" end))
                      (4 (concat "^" tab "\\{2\\}+" end))
                      (2 (concat "^" tab "\\{4\\}+" end))))
         (two (guess-style-how-many two-exp))
         (four (guess-style-how-many four-exp))
         (eight (guess-style-how-many eight-exp))
         (total (+ two four eight))
         (too-close-to-call (* guess-style-too-close-to-call total)))
    (when (< total guess-style-minimum-line-count)
      (guess-style-error "Not enough lines"))
    (or (if (> two four)
            (if (> two eight)
                (unless (< (- two (max four eight)) too-close-to-call) 2)
              (unless (< (- eight two) too-close-to-call) 8))
          (if (> four eight)
              (unless (< (- four (max two eight)) too-close-to-call) 4)
            (unless (< (- eight four) too-close-to-call) 8)))
        (guess-style-error "Too close to call"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar guess-style-lighter-format-func
  'guess-style-lighter-default-format-func
  "*Function used for formatting the lighter in `guess-style-info-mode'.
This has to be a function that takes no arguments and returns a info string
for the current buffer.")

(defun guess-style-get-indent ()
  (case major-mode
    (nxml-mode nxml-child-indent)
    (css-mode css-indent-offset)
    (otherwise (and (boundp 'c-buffer-is-cc-mode)
                    c-buffer-is-cc-mode
                    c-basic-offset))))

(defun guess-style-lighter-default-format-func ()
  (let ((indent-depth (guess-style-get-indent)))
    (concat (when indent-depth (format " >%d" indent-depth))
            " " (if indent-tabs-mode (format "t%d" tab-width) "spc"))))

(define-minor-mode guess-style-info-mode
  ""
  nil nil nil)

;; providing a lighter in `define-minor-mode' doesn't allow :eval forms
(add-to-list 'minor-mode-alist
             '(guess-style-info-mode
               ((:eval (funcall guess-style-lighter-format-func)))))

(provide 'guess-style)
;;; guess-style.el ends here
