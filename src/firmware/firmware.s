nop # Error trap handler
j system_trap # SYSTEM trap handler

system_trap:
mret # Any SYSTEM instruction will hand control
     # back to normal mode.

