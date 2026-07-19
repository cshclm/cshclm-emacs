;;; org-remove-scheduled-time.el --- Remove time from repeating scheduled timestamps -*- lexical-binding: t; -*-

;; This function removes the time portion (HH:MM) from a SCHEDULED
;; timestamp while preserving the date and any repeater interval.

(require 'org-element)

(defun org-remove-scheduled-time ()
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

(provide 'org-remove-scheduled-time)

;;; org-remove-scheduled-time.el ends here
