# Activate the lemon-lucifer project when opening RStudio Server
setHook("rstudio.sessionInit", function(newSession) {
  if (newSession && is.null(rstudioapi::getActiveProject()))
    rstudioapi::openProject("lemon-lucifer")
}, action = "append")
