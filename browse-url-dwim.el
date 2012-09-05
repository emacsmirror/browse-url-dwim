;;; browse-url-dwim.el --- Context-sensitive external browse URL or Internet search
;;
;; Copyright (c) 2012 Roland Walker
;;
;; Author: Roland Walker <walker@pobox.com>
;; Homepage: http://github.com/rolandwalker/browse-url-dwim
;; URL: http://raw.github.com/rolandwalker/browse-url-dwim/master/browse-url-dwim.el
;; Version: 0.5.0
;; Last-Updated: 1 Sep 2012
;; EmacsWiki: BrowseUrlDwim
;; Keywords: hypermedia
;; Package-Requires: ((string-utils 0.0.3))
;;
;; Simplified BSD License
;;
;;; Commentary:
;;
;; Quickstart
;;
;;     (require 'browse-url-dwim)
;;     (browse-url-dwim-mode 1)
;;     place the cursor on a URL
;;     press "C-c b"
;;     select some text
;;     press "C-c g"
;;
;; Explanation
;;
;; This small library for calling external browsers combines some of
;; the functionality of `browse-url' and `thingatpt'.
;;
;; Three interactive commands are provided:
;;
;;     `browse-url-dwim'
;;     `browse-url-dwim-search'
;;     `browse-url-dwim-guess'
;;
;; each of which tries to extract URLs or meaningful terms from
;; context in the current buffer, and prompts for input when unable
;; to do so.
;;
;; The context-sensitive matching of `browse-url-dwim' tries to do
;; _less_ overall than the default behavior of `thingatpt', on the
;; theory that `thingatpt' matches too liberally.  However,
;; `browse-url-dwim' does recognize some URLs that the default
;; `browse-url' ignores, such as "www.yahoo.com" without the
;; leading "http://".
;;
;; To use `browse-url-dwim', add the following to your ~/.emacs file
;;
;;     (require 'browse-url-dwim)      ; load library
;;     (browse-url-dwim-mode 1)        ; install aliases and keybindings
;;
;; Then place the cursor on a URL and press
;;
;;     C-c b                           ; b for browse
;;
;; or select some text and press
;;
;;     C-c g                           ; g for Google
;;
;; or (equivalently)
;;
;;     M-x browse RET
;;     M-x google RET
;;
;; Outside the USA
;;
;; If you are outside the USA, you will want to customize
;; `browse-url-dwim-permitted-tlds' so that your favorite
;; top-level domains will be recognized in context.  You
;; may also wish to customize `browse-url-dwim-search-url'
;; to point at an appropriate search engine.
;;
;; See Also
;;
;;     M-x customize-group RET browse-url-dwim RET
;;     M-x customize-group RET browse-url RET
;;
;; Notes
;;
;; To control which browser is invoked, see the underlying library
;; `browse-url'.
;;
;; By default, the minor mode binds and aliases `browse-url-dwim-guess'
;; for Internet search, but the user might prefer to bind
;; `browse-url-dwim-search', which has less DWIM:
;;
;;     (define-key browse-url-dwim-map (kbd "C-c g") 'browse-url-dwim-search)
;;
;; Compatibility and Requirements
;;
;;     Tested on GNU Emacs versions 23.3 and 24.1
;;
;;     Uses if present: string-utils.el
;;
;; Bugs
;;
;;     `thing-at-point-short-url-regexp' requires at least two dots in the hostname,
;;     so "domain.com" cannot be detected at point, whereas the following will be:
;;     "www.domain.com" or "http://domain.com"
;;
;;     `url-normalize-url' doesn't do much.  Multiple slashes should be removed
;;     for a start.
;;
;; TODO
;;
;;     Support thing-nearest-point, with fallback.
;;
;;     Test various schemes, esp "file:", "mailto:", and "ssh:".
;;
;;     Extract multiple URLs from region and browse to all.
;;
;;; License
;;
;;     Simplified BSD License
;;
;;     Copyright (c) 2012, Roland Walker
;;     All rights reserved.
;;
;;     Redistribution and use in source and binary forms, with or
;;     without modification, are permitted provided that the following
;;     conditions are met:
;;
;;        1. Redistributions of source code must retain the above
;;           copyright notice, this list of conditions and the following
;;           disclaimer.
;;
;;        2. Redistributions in binary form must reproduce the above
;;           copyright notice, this list of conditions and the following
;;           disclaimer in the documentation and/or other materials
;;           provided with the distribution.
;;
;;     This software is provided by Roland Walker "AS IS" and any express
;;     or implied warranties, including, but not limited to, the implied
;;     warranties of merchantability and fitness for a particular
;;     purpose are disclaimed.  In no event shall Roland Walker or
;;     contributors be liable for any direct, indirect, incidental,
;;     special, exemplary, or consequential damages (including, but not
;;     limited to, procurement of substitute goods or services; loss of
;;     use, data, or profits; or business interruption) however caused
;;     and on any theory of liability, whether in contract, strict
;;     liability, or tort (including negligence or otherwise) arising in
;;     any way out of the use of this software, even if advised of the
;;     possibility of such damage.
;;
;;     The views and conclusions contained in the software and
;;     documentation are those of the authors and should not be
;;     interpreted as representing official policies, either expressed
;;     or implied, of Roland Walker.
;;
;;; Code:
;;

;;; requires

;; for let*, callf, callf2
(eval-when-compile
  (defvar thing-at-point-short-url-regexp)
  (require 'cl))

(require 'string-utils nil t)

(autoload 'thing-at-point         "thingatpt"   "Return the THING at point."                       nil)
(autoload 'url-generic-parse-url  "url-parse"   "Return an URL-struct of the parts of URL."        nil)
(autoload 'url-normalize-url      "url-util"    "Return a 'normalized' version of URL."            nil)
(autoload 'url-hexify-string      "url-util"    "Return a new string that is STRING URI-encoded."  nil)
(autoload 'browse-url             "browse-url"  "Ask a WWW browser to load a URL."                 t)

(declare-function string-utils-has-darkspace-p "string-utils.el")

;;; constants

(defconst browse-url-dwim-google-fragment "http://www.google.com/search?ie=utf-8&oe=utf-8&q="
  "URL fragment which can be used to construct a Google search.")

;;; customizable variables

;;;###autoload
(defgroup browse-url-dwim nil
  "Context-sensitive external browse URL or Internet search."
  :version "0.5.0"
  :link '(emacs-commentary-link "browse-url-dwim")
  :prefix "browse-url-dwim-"
  :group 'external
  :group 'browse-url
  :group 'hypermedia
  :group 'convenience)

(defcustom browse-url-dwim-less-feedback nil
  "Give less echo area feedback."
  :type 'boolean
  :group 'browse-url-dwim)

(defcustom browse-url-dwim-always-confirm-extraction t
  "Always prompt for confirmation of URLs detected from context."
  :type 'boolean
  :group 'browse-url-dwim)

(defcustom browse-url-dwim-permitted-tlds '(
                                            "com"
                                            "edu"
                                            "gov"
                                            "mil"
                                            "net"
                                            "org"
                                            )
  "Top-level domains used when trying to recognize URLs in text.

This is purposefully set to a minimal list by default to keep
`thing-at-point' from over-guessing when trying to extract a URL
from context.  Other top-level domains are also recognized in
fully-qualified URLs which include a scheme (eg \"http\")."
  :type '(repeat string)
  :group 'browse-url-dwim)

(defcustom browse-url-dwim-permitted-schemes '(
                                               "http"
                                               "https"
                                               "ftp"
                                               )
  "URI schemes recognized by `browse-url-dwim'.

This is purposefully set to a minimal list by default to keep
`thing-at-point' from over-guessing.  Other schemes are not
recognized when extracting a URL from context.

For URLs given at interactive prompts, this limit does not
apply."
  :type '(repeat string)
  :group 'browse-url-dwim)

(defcustom browse-url-dwim-install-aliases t
  "Whether to install command aliases for `browse-url-dwim'.

When this option is set and `browse-url-dwim-mode' is turned
on, `browse' is aliased to `browse-url-dwim' and `google' is
aliased to `browse-url-dwim-guess'."
  :type 'boolean
  :group 'browse-url-dwim)

(defcustom browse-url-dwim-search-url browse-url-dwim-google-fragment
  "URL fragment used to construct Internet searches.

The default string uses Google."
  :type 'string
  :group 'browse-url-dwim)

;;;###autoload
(defgroup browse-url-dwim-keys nil
  "Key bindings for `browse-url-dwim-mode'."
  :group 'browse-url-dwim)

(defcustom browse-url-dwim-keystrokes '("C-c b")
  "Key sequences to activate an external web browser.

These key sequences will invoke `browse-url-dwim' when
`browse-url-dwim-mode' is active.

The format for key sequences is as defined by `kbd'."
  :type '(repeat string)
  :group 'browse-url-dwim-keys)

(defcustom browse-url-dwim-guess-keystrokes '("C-c g")
  "Key sequences to activate an Internet search in an external browser.

These key sequences will invoke `browse-url-dwim-guess' when
`browse-url-dwim-mode' is active.

The format for key sequences is as defined by `kbd'."
  :type '(repeat string)
  :group 'browse-url-dwim-keys)

(defcustom browse-url-dwim-search-keystrokes nil
  "Key sequences to activate an Internet search in an external browser.

These key sequences will invoke `browse-url-dwim-search' when
`browse-url-dwim-mode' is active.

The format for key sequences is as defined by `kbd'."
  :type '(repeat string)
  :group 'browse-url-dwim-keys)

;;; variables

(defvar browse-url-history-list nil
  "A list of strings entered at `browse-url' prompts.")

(defvar browse-url-dwim-host-mandatary-schemes
  '(
    "acap"
    "afs"
    "crid"
    "dict"
    "fish"
    "ftp"
    "git"
    "gopher"
    "h323"
    "http"
    "https"
    "iax"
    "icap"
    "imap"
    "ipp"
    "irc"
    "irc6"
    "ircs"
    "mms"
    "mmsh"
    "msrp"
    "mtqp"
    "mumble"
    "mvn"
    "nfs"
    "nntp"
    "pop"
    "rmi"
    "rsync"
    "rtmp"
    "rtsp"
    "rtspu"
    "service"       ; service can also have attributes, which url-generic-parse-url does not understand
    "sftp"
    "sgn"
    "sieve"
    "snmp"
    "ssh"
    "teamspeak"
    "telnet"
    "tftp"
    "tip"
    "tn3270"
    "vemmi"
    "webcal"
    "xmpp"
    "xri"
    "z39.50r"
    "z39.50s"
    )
  "URI schemes for which a host portion is mandatory.")

;; todo prepend a word-separator boundary
(defvar browse-url-dwim-prompt-list '(
                                      ("google\\." . "Google: ")
                                      ("yahoo\\."  . "Yahoo: ")
                                      ("bing\\."   . "Bing: ")
                                      )
  "Alist describing interactive prompts.

The car of each cell is a regexp which matches into the URL
fragment for creating a search.  The cdr of each cell is the
associated prompt.")

;;; keymaps

(defvar browse-url-dwim-mode-map (make-sparse-keymap)
  "Keymap for `browse-url-dwim-mode' minor-mode.")

(dolist (cmd '(browse-url-dwim browse-url-dwim-guess browse-url-dwim-search))
  (dolist (k (symbol-value (intern (concat (symbol-name cmd) "-keystrokes"))))
    (define-key browse-url-dwim-mode-map (read-kbd-macro k) cmd)))

;;; macros

(defmacro browse-url-dwim-called-interactively-p (&optional kind)
  "A backward-compatible version of `called-interactively-p'.

Optional KIND is as documented at `called-interactively-p'
in GNU Emacs 24.1 or higher."
  (if (eq 0 (cdr (subr-arity (symbol-function 'called-interactively-p))))
      '(called-interactively-p)
    `(called-interactively-p ,kind)))

;;; compatibility functions

(unless (fboundp 'string-utils-has-darkspace-p)
  ;; simplified version of function from string-utils.el
  (defun string-utils-has-darkspace-p (obj)
  "Test whether OBJ, when coerced to a string, has any non-whitespace characters.

Returns the position of the first non-whitespace character
on success."
  (let ((str-val (if (stringp obj) obj (format "%s" obj))))
    (string-match-p "[^ \t\n\r\f]" str-val))))

;;; utility functions

(defun browse-url-dwim-context-url ()
  "Find a Web URL at the point or in the region.

If there is an active region which looks like a URL, returns
that.

If `thing-at-point' finds a URL at the point, returns that.
However, note that `thing-at-point' here does not follow default
behavior, and is constrained narrowly to defined Web protocols
and popular top-level domains.

If no prospective URL is found, returns nil."

  (let ((thing-at-point-short-url-regexp (concat (if (boundp 'thing-at-point-short-url-regexp)
                                                     thing-at-point-short-url-regexp
                                                   "[-A-Za-z0-9]+\\.[-A-Za-z0-9.]+[^]\t\n\"'<>[^`{}]*[^]\t\n\"'<>[^`{}.,;]+")
                                                 "?\\."
                                                 (regexp-opt browse-url-dwim-permitted-tlds)))
        (case-fold-search t))
    (or (and (use-region-p)
             (browse-url-dwim-coerce-to-web-url (buffer-substring-no-properties (region-beginning) (region-end))))
        (browse-url-dwim-coerce-to-web-url (thing-at-point 'url)))))

(defun browse-url-dwim-get-url (&optional always-prompt prompt-string fallback-default)
  "Find a Web URL by context or user input.

First, attempt to find a Web URL by calling
`browse-url-dwim-context-url'.

If that fails, prompt the user.  User input is returned
without testing for validity.

If optional ALWAYS-PROMPT is set, always prompt the user, filling
in a default value from context if possible.  Otherwise, the
value of `browse-url-dwim-always-confirm-extraction' determines
prompting behavior.

PROMPT-STRING (if supplied) gives a string to use at the prompt.

FALLBACK-DEFAULT (if supplied) is used as an interactive default if
a candidate is not found by other means."
  (callf or always-prompt browse-url-dwim-always-confirm-extraction)
  (callf or prompt-string "Browse to page: ")
  (let ((extracted-text (browse-url-dwim-context-url))
        (entered-text ""))
    (when (or always-prompt
              (not extracted-text))
      (callf or extracted-text fallback-default)
      (callf browse-url-dwim-add-prompt-default prompt-string extracted-text)
      (setq entered-text (read-from-minibuffer prompt-string nil nil nil 'browse-url-history-list)))
    (if (string-utils-has-darkspace-p entered-text)
        entered-text
      extracted-text)))

(defun browse-url-dwim-coerce-to-web-url (url &optional any-scheme add-scheme)
  "Coerce URL to a string representing a valid web address.

Returns nil on failure.

If ANY-SCHEME is set, no restriction is placed on permitted
schemes in the URL.  Otherwise, `browse-url-dwim-permitted-schemes'
is consulted.

The scheme \"http://\" will be prepended in the absence of a
scheme.  The default scheme can be changed by passing ADD-SCHEME.
Note that ADD-SCHEME is a string which must include any required
colon and slash characters.

The value of `browse-url-dwim-permitted-tlds' is consulted when
determining whether to add a scheme."
  (unless (stringp 'add-scheme)
    (setq add-scheme "http://"))
  ;; stringify and clean up
  (unless (stringp url)
    (setq url (if url (format "%s" url) "")))
  (callf substring-no-properties url)
  ;; must have non-whitespace
  (when (not (string-utils-has-darkspace-p url))
    (setq url nil))
  ;; add scheme when missing, if text otherwise looks like a URL
  (when (and url
             (not (aref (url-generic-parse-url url) 1))
             (string-match-p (concat "\\`[^/]+\\." (regexp-opt browse-url-dwim-permitted-tlds) "\\(/\\|\\'\\)") url))
    (callf2 concat add-scheme url))
  ;; invalid scheme
  (when (and url
             (not any-scheme)
             (not (member (aref (url-generic-parse-url url) 1) browse-url-dwim-permitted-schemes)))
    (setq url nil))
  ;; no hostname
  (when (and url
             (not (aref (url-generic-parse-url url) 4)))
    (setq url nil))
  ;; invalid hostname
  (when (and url
             (member (aref (url-generic-parse-url url) 1) browse-url-dwim-host-mandatary-schemes)
             (not (string-match-p "\\." (aref (url-generic-parse-url url) 4))))
    (setq url nil))
  (when url
    (url-normalize-url url)))

(defun browse-url-dwim-make-search-prompt (search-url)
  "Given SEARCH-URL, return a prompt string.

The prompt string is based on `browse-url-dwim-prompt-list'."
  (let ((prompt (catch 'match
                  (dolist (cell browse-url-dwim-prompt-list)
                    (when (and (stringp search-url)
                               (string-match-p (car cell) search-url))
                      (throw 'match (cdr cell)))))))
    (or prompt "Internet Search: ")))

(defun browse-url-dwim-add-prompt-default (prompt-string default-string &optional length-limit)
  "Using PROMPT-STRING as a base, insert DEFAULT-STRING.

The revised string is returned.

Optional LENGTH-LIMIT (default 40) limits the length of the
inserted default.

PROMPT-STRING is expected to end with \": \", which will be added if
not present.

DEFAULT-STRING may be nil, in which case no default is inserted."
  (setq length-limit (min (or length-limit 40) (length default-string)))
  (save-match-data
    (if (not default-string)
        (replace-regexp-in-string "[: ]*\\'" ": " prompt-string)
    (callf substring default-string 0 length-limit)
    (replace-regexp-in-string "[: ]*\\'" (concat " (" default-string "): ") prompt-string))))

;;; minor mode definition

;;;###autoload
(define-minor-mode browse-url-dwim-mode
  "Turn on `browse-url-dwim-mode'.

Turning on `browse-url-dwim' will activate keybindings as defined
in `customize'.  It may also install a command alias for `browse'
and `google' as controlled by `browse-url-dwim-install-aliases'.

When called interactively with no prefix argument this command
toggles the mode.  With a prefix argument, it enables the mode
if the argument is positive and otherwise disables the mode.

When called from Lisp, this command enables the mode if the
argument is omitted or nil, and toggles the mode if the argument
is 'toggle."
  :group 'browse-url-dwim
  :global t
  (cond
   (browse-url-dwim-mode
    (when browse-url-dwim-install-aliases
      (defalias 'browse 'browse-url-dwim)
      (defalias 'google 'browse-url-dwim-guess))
    (when (and (browse-url-dwim-called-interactively-p 'interactive)
               (not browse-url-dwim-less-feedback))
      (message "browse-url-dwim mode enabled")))
   (t
    (when browse-url-dwim-install-aliases
      (when (eq (symbol-function 'browse) 'browse-url-dwim)
        (defalias 'browse nil))
      (when (eq (symbol-function 'google) 'browse-url-dwim-guess)
        (defalias 'google nil)))
    (when (and (browse-url-dwim-called-interactively-p 'interactive)
               (not browse-url-dwim-less-feedback))
      (message "browse-url-dwim mode disabled")))))

;;; interactive commands

;;;###autoload
(defun browse-url-dwim (url)
  "Opens a URL in an external browser.

When called interactively, `browse-url-dwim-get-url' will be
used to find an appropriate URL.

The browser used is as configured for `browse-url'."
  (interactive
   (list
    (browse-url-dwim-coerce-to-web-url (browse-url-dwim-get-url) t)))
  (browse-url url))

;;;###autoload
(defun browse-url-dwim-search (&optional text search-url guess)
  "Perform an Internet search for TEXT, or region, or interactive input.

If TEXT is a URL, browse to page directly.  Otherwise
invoke an Internet search using TEXT.  When called interactively,
TEXT may be taken from the region or entered at a prompt.

Optional SEARCH-URL specifies the URL fragment used to construct
the search request.  If not specified, the customizable variable
`browse-url-dwim-search-url' is used.

If GUESS is non-nil, an attempt will be made to extract a URL from
the context around the point.  If so, this command is equivalent to
`browse-url-dwim'."
  (interactive)
  (callf or search-url browse-url-dwim-search-url)
  (unless text
    (let* ((region (if (use-region-p) (buffer-substring-no-properties (region-beginning) (region-end))))
           (region-url (browse-url-dwim-coerce-to-web-url region))
           (prompt-string (browse-url-dwim-make-search-prompt search-url))
           (entered-text ""))
      (setq text (or region-url region))
      (when (or (null text)
                browse-url-dwim-always-confirm-extraction)
        (callf or text (thing-at-point 'symbol))
        (when (stringp text)
          (callf substring-no-properties text))
        (callf browse-url-dwim-add-prompt-default prompt-string text)
        (if guess
            (setq entered-text (browse-url-dwim-get-url nil (browse-url-dwim-make-search-prompt browse-url-dwim-search-url) text))
          (setq entered-text (read-from-minibuffer prompt-string nil nil nil 'browse-url-history-list))))
      (when (string-utils-has-darkspace-p entered-text)
        (setq text entered-text))))
  (cond
    ((not (string-utils-has-darkspace-p text))
     (error "No valid query or URL"))
    ((browse-url-dwim-coerce-to-web-url text)
     (browse-url-dwim (browse-url-dwim-coerce-to-web-url text)))
    (t
     (browse-url-dwim (concat search-url (url-hexify-string text))))))

;;;###autoload
(defun browse-url-dwim-guess (&optional text search-url)
  "Perform Internet search or browse to URL under point, according to context.

Identical to calling `browse-url-dwim-search' with GUESS set
to non-nil.

Optional TEXT is a string to be submitted to the search
engine.

Optional SEARCH-URL overrides the default search engine
URL."
  (interactive)
  (browse-url-dwim-search text search-url 'guess))

(provide 'browse-url-dwim)

;;
;; Emacs
;;
;; Local Variables:
;; indent-tabs-mode: nil
;; mangle-whitespace: t
;; require-final-newline: t
;; coding: utf-8
;; byte-compile-warnings: (not cl-functions)
;; End:
;;
;; LocalWords: BrowseUrlDwim dwim google utils mailto callf thingatpt
;; LocalWords: util struct http https bing Alist DWIM Bing
;;

;;; browse-url-dwim.el ends here
