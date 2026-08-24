report_emit_stdout(){
(( $# == 1 ))||return 64
print -r -- "$1"
}
