;;; pilish-bang.el --- `!'/`!!' shell commands for Pilish -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Adds pi's own `!command'/`!!command' shell-alias syntax (see
;; https://pi.dev/docs/latest/shell-aliases) to Pilish's input buffer,
;; without forking any of Pilish's own files.
;;
;; Typing `!command' and sending it runs COMMAND via pi's existing
;; `bash' RPC and records the result in pi's conversation context;
;; `!!command' runs it excluded from context.  Either form bypasses
;; the model entirely.  This is implemented purely as advice around
;; the two public entry points `pilish-send' and `pilish-abort', so it
;; layers on top of an unmodified Pilish install the same way
;; `pilish-evil' layers on Evil.
;;
;; Load it after Pilish, for example:
;;
;;   (require 'pilish-bang)
;;
;; Limitation: a `!'/`!!' command run in a past session is not
;; redisplayed after reloading that session (Pilish's history-replay
;; dispatch has no extension point for it); the command and its
;; output remain in the session's JSONL file regardless.

;;; Code:

(require 'pilish)

(defvar-local pilish-bang--running nil
  "Non-nil while a `!'/`!!' shell command is executing via RPC.")

(defun pilish-bang--command-info (text)
  "Return (COMMAND . EXCLUDE-FROM-CONTEXT) when TEXT is a `!' shell command.
TEXT prefixed with a single `!' runs COMMAND and records its output in
pi's conversation context.  A `!!' prefix runs COMMAND excluded from
context.  Returns nil when TEXT does not start with `!' or COMMAND is
empty after trimming the prefix."
  (when (and (stringp text) (string-prefix-p "!" text))
    (let* ((excluded (string-prefix-p "!!" text))
           (command (string-trim (substring text (if excluded 2 1)))))
      (unless (string-empty-p command)
        (cons command excluded)))))

(defun pilish-bang--display (command result &optional excluded)
  "Display a `!'/`!!' shell COMMAND and its RESULT in the chat buffer.
RESULT is a plist with :output and :exitCode, matching pi's `bash' RPC
response shape.  EXCLUDED is non-nil when the command's output was kept
out of pi's conversation context.  Reuses the same tool-block rendering
as the model-invoked `bash' tool for visual consistency."
  (let* ((args (list :command command))
         (output (pilish--render-safe-string (plist-get result :output)))
         (content (vector (list :type "text" :text output)))
         (cancelled (pilish--normalize-boolean (plist-get result :cancelled)))
         (exit-code (plist-get result :exitCode))
         (is-error (or cancelled
                       (and (numberp exit-code) (/= exit-code 0))))
         (block (pilish--display-tool-start "bash" args)))
    (pilish--display-tool-end "bash" args content nil is-error block)
    (when excluded
      (pilish--append-to-chat
       (propertize "(excluded from pi's context)\n" 'face 'pilish-timestamp)))))

(defun pilish-bang--run (chat-buf command exclude-from-context)
  "Run COMMAND as a shell command in CHAT-BUF's pi session via RPC.
EXCLUDE-FROM-CONTEXT is non-nil for a `!!' command."
  (let ((proc (pilish--get-process)))
    (cond
     ((null proc)
      (message "Pi: No process available - try M-x pilish-reload or C-c C-p R"))
     ((not (process-live-p proc))
      (message "Pi: Process died - try M-x pilish-reload or C-c C-p R"))
     (t
      (with-current-buffer chat-buf
        (setq pilish-bang--running t))
      (pilish--rpc-async
       proc
       (list :type "bash" :command command
             :excludeFromContext (if exclude-from-context t :json-false))
       (lambda (response)
         (when (buffer-live-p chat-buf)
           (with-current-buffer chat-buf
             (setq pilish-bang--running nil)
             (if (eq (plist-get response :success) t)
                 (pilish-bang--display
                  command (plist-get response :data) exclude-from-context)
               (pilish--display-error
                (format "Shell command failed: %s"
                        (or (pilish--normalize-string-or-null
                             (plist-get response :error))
                            "unknown error"))))))))))))

(defun pilish-bang--send-advice (orig-fn)
  "Call ORIG-FN for non-`!' input; dispatch `!'/`!!' input as a shell command.
ORIG-FN is `pilish-send's normal prompt/follow-up handling."
  (let* ((text (string-trim (buffer-string)))
         (chat-buf (pilish--get-chat-buffer))
         (info (pilish-bang--command-info text)))
    (cond
     ((null info)
      (funcall orig-fn))
     ((pilish--get-prompt-image)
      (message "Pi: Attached images cannot be sent with shell commands"))
     ((and chat-buf (buffer-local-value 'pilish-bang--running chat-buf))
      (message "Pi: A shell command is already running - press C-c C-c to cancel it first"))
     (t
      (pilish--accept-input-text text)
      (pilish--maybe-hide-input-window)
      (pilish-bang--run chat-buf (car info) (cdr info))))))

(advice-add 'pilish-send :around #'pilish-bang--send-advice)

(defun pilish-bang--abort-advice (orig-fn)
  "Around-advice for `pilish-abort': also abort a running shell command.
ORIG-FN always runs afterward, so its unrelated stop handling (sending,
streaming, compacting, preflight) is unaffected."
  (when-let* ((chat-buf (pilish--get-chat-buffer)))
    (with-current-buffer chat-buf
      (when pilish-bang--running
        (when-let* ((proc (pilish--get-process)))
          (pilish--rpc-async proc '(:type "abort_bash") #'ignore))
        (message "Pi: Aborting shell command..."))))
  (funcall orig-fn))

(advice-add 'pilish-abort :around #'pilish-bang--abort-advice)

(provide 'pilish-bang)
;;; pilish-bang.el ends here
