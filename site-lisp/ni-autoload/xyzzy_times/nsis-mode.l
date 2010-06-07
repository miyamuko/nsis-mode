(export 'ed::nsis-mode "ed")
(autoload 'nsis-mode "nsis-mode" t)
(pushnew '("\\.ns[ih]$" . nsis-mode) *auto-mode-alist* :test 'equal)
