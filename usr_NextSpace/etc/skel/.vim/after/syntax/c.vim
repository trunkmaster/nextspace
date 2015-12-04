"
" Folding for C files
"

"if !exists("b:is_objc")
"    syn region cFunctionFold start="^.*\s*(.*)\n{" end="^}" transparent fold
"endif

syn region cFunctionFold start="^{" end="^}" transparent fold
syn clear cBlock