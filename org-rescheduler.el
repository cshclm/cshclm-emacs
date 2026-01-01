;;; org-rescheduler.el --- Remove timestamps when repeating  -*- lexical-binding: t; -*-

;; This function removes the time portion (HH:MM) from a SCHEDULED
;; timestamp while preserving the date and any repeater interval.

(require 'org-element)

(defcustom org-rescheduler-ignore-property "RESCHEDULER_IGNORE"
  "Org property to be used for preventing org-rescheduler from applying when enabled"
  :group 'org-rescheduler
  :type 'string)

(defun org-rescheduler-remove-scheduled-time ()
  "Remove the time (HH:MM) from the SCHEDULED timestamp at point.
Preserves the date and any repeater interval (e.g., +1d, +1w)."
  (interactive)
  (let ((element (org-element-at-point)))
    (save-excursion
      ;; Navigate to the element's begin to search forward
      (goto-char (org-element-property :begin element))
      (let ((end (org-element-property :end element)))
        (when (re-search-forward org-scheduled-time-regexp end t)
          (let* ((ts-begin (match-beginning 1))
                 (ts-end (match-end 1))
                 (ts-string (match-string 1))
                 ;; Parse timestamp
                 (ts (with-temp-buffer
                       (insert "<" ts-string ">")
                       (goto-char (point-min))
                       (org-element-timestamp-parser))))
            (when (org-element-property :hour-start ts)
              ;; Clear time properties
              (org-element-put-property ts :hour-start nil)
              (org-element-put-property ts :minute-start nil)
              (org-element-put-property ts :hour-end nil)
              (org-element-put-property ts :minute-end nil)
              (org-element-put-property ts :range-type nil)
              (org-element-put-property ts :type 'active)
              ;; Replace timestamp in buffer
              (let ((new-ts (org-element-timestamp-interpreter ts nil)))
                ;; Strip the brackets that interpreter adds
                (setq new-ts (substring new-ts 1 -1))
                (goto-char ts-begin)
                (delete-region ts-begin ts-end)
                (insert new-ts)))))))))

(defun org-rescheduler-enabled-p ()
  "Predicate. Returns `t' if `org-rescheduler' is enabled; nil otherwise."
  (not (null (member #'org-rescheduler-activity-hook org-after-todo-state-change-hook))))

(defun org-rescheduler-activity-hook ()
  "Hook to run in order to trigger snoozing behaviour."
  (when (and (org-entry-is-done-p) (org-get-repeat)
             (not (org-entry-get nil org-rescheduler-ignore-property 'selective)))
    (org-rescheduler-remove-scheduled-time)))

(defun org-rescheduler-enable ()
  "Enable `org-rescheduler'."
  (interactive)
  (add-hook 'org-after-todo-state-change-hook #'org-rescheduler-activity-hook)
  (message "Org rescheduler enabled"))

(defun org-rescheduler-disable ()
  (interactive)
  (remove-hook 'org-after-todo-state-change-hook #'org-rescheduler-activity-hook)
  (message "Org rescheduler disabled"))

(defun org-rescheduler--select-target-state (enabledp input)
  (cond
   ((null input) (if enabledp 'deactivated 'activated))
   ((and (numberp input) (zerop input)) 'deactivated)
   (t 'activated)))

(defun org-rescheduler--current-state (current-state)
  (if (org-rescheduler-enabled-p)
      'activated
    'deactivated))

(defun org-rescheduler--select-state-transition (enabledp input)
  (let ((current-state (org-rescheduler--current-state enabledp))
        (target-state (org-rescheduler--select-target-state enabledp input)))
    (unless (equal current-state target-state)
      (cl-case target-state
        (activated 'activate)
        (deactivated 'deactivate)))))

(defun org-rescheduler (&optional input)
  "Enable or disable `org-rescheduler'. Toggle enabled state if `input' is nil and disable when `input' is zero.  Otherwise enable."
  (interactive "p")
  (cl-case (org-rescheduler--select-state-transition (org-rescheduler-enabled-p) input)
    (activate (org-rescheduler-enable))
    (deactivate (org-rescheduler-disable))))

(provide 'org-rescheduler)

;;; org-rescheduler.el ends here
