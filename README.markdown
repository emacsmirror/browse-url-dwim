[![Build Status](https://secure.travis-ci.org/rolandwalker/browse-url-dwim.png)](http://travis-ci.org/rolandwalker/browse-url-dwim)

Overview
========

Context-sensitive external browse URL or Internet search from Emacs.

Quickstart
----------

    (require 'browse-url-dwim)
    (browse-url-dwim-mode 1)
    place the cursor on a URL
    press "C-c b"
    select some text
    press "C-c g"

browse-url-dwim
---------------

This small library for calling external browsers combines some of
the functionality of `browse-url` and `thingatpt`.

Three interactive commands are provided:

    `browse-url-dwim`
    `browse-url-dwim-search`
    `browse-url-dwim-guess`

each of which tries to extract URLs or meaningful terms from
context in the current buffer, and prompts for input when unable
to do so.

The context-sensitive matching of `browse-url-dwim` tries to do
*less* overall than the default behavior of `thingatpt`, on the
theory that `thingatpt` matches too liberally.  However,
`browse-url-dwim` does recognize some URLs that the default
`browse-url` ignores, such as "www.yahoo.com" without the
leading "http://".

To use `browse-url-dwim`, add the following to your ~/.emacs file

    (require 'browse-url-dwim)      ; load library
    (browse-url-dwim-mode 1)        ; install aliases and keybindings

Then place the cursor on a URL and press

    C-c b                           ; b for browse

or select some text and press

    C-c g                           ; g for Google

or (equivalently)

    M-x browse RET
    M-x google RET

Outside the USA
---------------

If you are outside the USA, you will want to customize
`browse-url-dwim-permitted-tlds` so that your favorite
top-level domains will be recognized in context.  You
may also wish to customize `browse-url-dwim-search-url`
to point at an appropriate search engine.

Notes
-----

To control which browser is invoked, see the underlying library
`browse-url`.

By default, the minor mode binds and aliases `browse-url-dwim-guess`,
for Internet search, but the user might prefer to bind
`browse-url-dwim-search`, which has less DWIM:

    (define-key browse-url-dwim-map (kbd "C-c g") 'browse-url-dwim-search)

Compatibility and Requirements
------------------------------

Tested on GNU Emacs versions 23.3 and 24.1

Uses if present: [string-utils.el](http://github.com/rolandwalker/string-utils)
