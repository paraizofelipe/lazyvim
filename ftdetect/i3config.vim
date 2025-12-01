" Detect i3 config files
au BufRead,BufNewFile */i3/config set filetype=i3config
au BufRead,BufNewFile */i3/config.d/* set filetype=i3config
au BufRead,BufNewFile *.i3config set filetype=i3config
