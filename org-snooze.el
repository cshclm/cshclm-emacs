;; org-snooze.el --- Automatic rescheduling of entries upon snoozing in org-mode.

;; Copyright (C) 2024 Chris Mann

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(require 'org)

(defgroup org-snooze nil
  "Options relating to snoozing in org-mode."
  :tag "Org Snooze"
  :group 'org-progress)

(defcustom org-snooze-until-default-time "+2d"
  "Default TIME upon to use upon snoozing.

See documentation for the \"TIME\" input under `org-schedule' for more."
  :group 'org-snooze
  :type 'string)

(defcustom org-snooze-property "SNOOZE_UNTIL"
  "Org property to be used for overriding `org-snooze-until-default-time'"
  :group 'org-snooze
  :type 'string)

(defcustom org-snooze-todo-keyword "SNOOZE"
  "Todo keyword for triggering snooze."
  :group 'org-snooze
  :type 'string)

(defcustom org-snooze-original-todo-keyword "TODO"
  "Todo keyword to use in the event a \"REPEAT_TO_STATE\" property is not found."
  :group 'org-snooze
  :type 'string)

(defun org-snooze-activity-hook ()
  "Hook to run in order to trigger snoozing behaviour."
  (when (string= org-state org-snooze-todo-keyword)
    (org-schedule nil (or (org-entry-get nil org-snooze-property 'selective)
                          org-snooze-until-default-time))
    (org-todo (or (org-entry-get nil "REPEAT_TO_STATE" 'selective) org-snooze-original-todo-keyword))))

(add-hook 'org-after-todo-state-change-hook #'org-snooze-activity-hook)

(provide 'org-snooze)

;; org-snooze.el ends here
