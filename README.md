# guess-style

## What's this for?
Guess variables like c-basic-offset, tab-width and indent-tabs-mode automatically.

## Configuration
Add the following to your .emacs:

```elisp
(add-to-path 'load-path "/path/to/guess-style")
(autoload 'guess-style-set-variable "guess-style" nil t)
(autoload 'guess-style-guess-variable "guess-style")
(autoload 'guess-style-guess-all "guess-style" nil t)
```
## Usage
To guess variables when a major mode is loaded, add guess-style-guess-all to that mode's hook like this: (add-hook 'c-mode-common-hook 'guess-style-guess-all)

To (permanently) override values use guess-style-set-variable. To change what variables are guessed, customize guess-style-guesser-alist.

To show some of the guessed variables in the mode-line, enable guess-style-info-mode. You can do this by adding this to your .emacs:
```elisp
(global-guess-style-info-mode 1)
```
# Feedback
If you have any feedback, please email me.