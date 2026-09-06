-- DMS Window Rules — managed by DankMaterialShell
-- Do not edit manually; changes may be overwritten

-- DMS-RULE: id=dms_rule_0, name=
hl.window_rule({ match = { class = ".*" }, float = true })

-- DMS-RULE: id=dms-floating-windows, name=DMS Floating Windows
hl.window_rule({ match = { class = "^com.danklinux.dms$" }, float = true })
