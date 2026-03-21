       identification division.
       program-id. cobdown.

       environment division.
       input-output section.
       file-control.
           select markdown-input assign to dynamic ws-input-path
               organization is line sequential.
           select html-output assign to dynamic ws-output-path
               organization is line sequential.

       data division.
       file section.
       fd  markdown-input.
       01  markdown-record                 pic x(2048).

       fd  html-output.
       01  html-record                     pic x(16384).

       working-storage section.
       01  ws-paths.
           05 ws-input-path                pic x(512).
           05 ws-output-path               pic x(512).

       01  ws-lines.
           05 ws-line-count                pic 9(4) comp value 0.
           05 ws-line-index                pic 9(4) comp value 0.
           05 ws-line-entry occurs 4000 times.
               10 ws-line-text             pic x(2048).
               10 ws-line-length           pic 9(4) comp.

       01  ws-state.
           05 ws-eof                       pic x value "N".
           05 ws-skip-next                 pic x value "N".
           05 ws-line-consumed             pic x value "N".
           05 ws-paragraph-open            pic x value "N".
           05 ws-code-open                 pic x value "N".
           05 ws-blockquote-depth          pic 9(2) comp value 0.
           05 ws-list-depth                pic 9(2) comp value 0.
           05 ws-indent                    pic 9(4) comp value 0.
           05 ws-quote-depth               pic 9(2) comp value 0.
           05 ws-target-depth              pic 9(2) comp value 0.
           05 ws-current-list-type         pic x value space.
           05 ws-list-marker-length        pic 9(4) comp value 0.
           05 ws-heading-level             pic 9 comp value 0.
           05 ws-next-length               pic 9(4) comp value 0.
           05 ws-work-length               pic 9(4) comp value 0.
           05 ws-content-start             pic 9(4) comp value 0.
           05 ws-hard-break                pic x value "N".
           05 ws-all-same                  pic x value "N".
           05 ws-digit-seen                pic x value "N".
           05 ws-close-current-li          pic x value "N".
           05 ws-meaningful-count          pic 9(4) comp value 0.
           05 ws-hr-char                   pic x value space.

       01  ws-current.
           05 ws-raw-line                  pic x(2048).
           05 ws-inner-line                pic x(2048).
           05 ws-next-line                 pic x(2048).
           05 ws-code-line                 pic x(2048).
           05 ws-item-text                 pic x(2048).
           05 ws-output-line               pic x(16384).
           05 ws-paragraph-buffer          pic x(16384).

       01  ws-list-stack.
           05 ws-list-entry occurs 20 times.
               10 ws-stack-indent          pic 9(4) comp.
               10 ws-stack-type            pic x.
               10 ws-stack-item-open       pic x.

       01  ws-inline.
           05 ws-source-text               pic x(4096).
           05 ws-source-length             pic 9(5) comp value 0.
           05 ws-source-backup             pic x(4096).
           05 ws-source-backup-length      pic 9(5) comp value 0.
           05 ws-target-text               pic x(16384).
           05 ws-target-length             pic 9(5) comp value 0.
           05 ws-saved-target              pic x(16384).
           05 ws-saved-target-length       pic 9(5) comp value 0.
           05 ws-segment-text              pic x(16384).
           05 ws-segment-length            pic 9(5) comp value 0.
           05 ws-temp-escaped-1            pic x(2048).
           05 ws-temp-escaped-1-length     pic 9(5) comp value 0.
           05 ws-temp-escaped-2            pic x(2048).
           05 ws-temp-escaped-2-length     pic 9(5) comp value 0.
           05 ws-link-text                 pic x(1024).
           05 ws-link-url                  pic x(1024).
           05 ws-image-alt                 pic x(1024).
           05 ws-image-url                 pic x(1024).
           05 ws-link-text-length          pic 9(4) comp value 0.
           05 ws-link-url-length           pic 9(4) comp value 0.
           05 ws-image-alt-length          pic 9(4) comp value 0.
           05 ws-image-url-length          pic 9(4) comp value 0.
           05 ws-inline-pos                pic 9(5) comp value 0.
           05 ws-strong-open               pic x value "N".
           05 ws-em-open                   pic x value "N".
           05 ws-code-span-open            pic x value "N".

       01  ws-work.
           05 ws-calc-text                 pic x(16384).
           05 ws-calc-max                  pic 9(5) comp value 0.
           05 ws-calc-length               pic 9(5) comp value 0.
           05 ws-char                      pic x value space.
           05 ws-char-2                    pic x value space.
           05 ws-heading-text              pic x value space.
           05 ws-i                         pic 9(5) comp value 0.
           05 ws-j                         pic 9(5) comp value 0.
           05 ws-k                         pic 9(5) comp value 0.

       procedure division.
       main.
           perform initialize-program
           perform read-paths
           perform load-input-file
           perform write-html-document
           stop run.

       initialize-program.
           move spaces to ws-input-path ws-output-path ws-paragraph-buffer
           perform varying ws-i from 1 by 1 until ws-i > 20
               move 0 to ws-stack-indent(ws-i)
               move space to ws-stack-type(ws-i) ws-stack-item-open(ws-i)
           end-perform.

       read-paths.
           display "Input Markdown path:"
           accept ws-input-path
           display "Output HTML path:"
           accept ws-output-path
           perform trim-input-path
           perform trim-output-path.

       trim-input-path.
           move ws-input-path to ws-calc-text
           move 512 to ws-calc-max
           perform calculate-length
           perform varying ws-i from 1 by 1 until ws-i > ws-calc-length
               move ws-input-path(ws-i:1) to ws-char
               if ws-char = """"
                   move space to ws-input-path(ws-i:1)
               end-if
           end-perform.

       trim-output-path.
           move ws-output-path to ws-calc-text
           move 512 to ws-calc-max
           perform calculate-length
           perform varying ws-i from 1 by 1 until ws-i > ws-calc-length
               move ws-output-path(ws-i:1) to ws-char
               if ws-char = """"
                   move space to ws-output-path(ws-i:1)
               end-if
           end-perform.

       load-input-file.
           open input markdown-input
           move "N" to ws-eof
           perform until ws-eof = "Y"
               read markdown-input
                   at end
                       move "Y" to ws-eof
                   not at end
                       if ws-line-count < 4000
                           add 1 to ws-line-count
                           move markdown-record
                               to ws-line-text(ws-line-count)
                           move ws-line-text(ws-line-count) to ws-calc-text
                           move 2048 to ws-calc-max
                           perform calculate-length
                           move ws-calc-length
                               to ws-line-length(ws-line-count)
                       end-if
               end-read
           end-perform
           close markdown-input.

       write-html-document.
           open output html-output
           move "<!DOCTYPE html>" to ws-output-line
           perform emit-line
           move "<html>" to ws-output-line
           perform emit-line
           move "<head>" to ws-output-line
           perform emit-line
           move "<meta charset=""utf-8"">" to ws-output-line
           perform emit-line
           move "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">"
               to ws-output-line
           perform emit-line
           move "<title>Converted Markdown</title>" to ws-output-line
           perform emit-line
           move "</head>" to ws-output-line
           perform emit-line
           move "<body>" to ws-output-line
           perform emit-line

           perform varying ws-line-index from 1 by 1
               until ws-line-index > ws-line-count
               if ws-skip-next = "Y"
                   move "N" to ws-skip-next
               else
                   move ws-line-text(ws-line-index) to ws-raw-line
                   move ws-line-length(ws-line-index) to ws-work-length
                   perform process-current-line
               end-if
           end-perform

           perform close-paragraph
           perform close-code-block
           perform close-all-lists
           move 0 to ws-target-depth
           perform adjust-blockquotes

           move "</body>" to ws-output-line
           perform emit-line
           move "</html>" to ws-output-line
           perform emit-line
           close html-output.

       process-current-line.
           move "N" to ws-line-consumed
           move ws-raw-line to ws-inner-line
           move ws-work-length to ws-next-length
           perform strip-blockquote-prefix

           if ws-code-open = "Y" and ws-line-consumed not = "Y"
               perform handle-code-line
           end-if
           if ws-line-consumed not = "Y" and ws-next-length = 0
               perform close-paragraph
               perform close-all-lists
               move "Y" to ws-line-consumed
           end-if
           if ws-line-consumed not = "Y"
               perform detect-code-block
           end-if
           if ws-line-consumed not = "Y"
               perform detect-setext-heading
           end-if
           if ws-line-consumed not = "Y"
               perform detect-atx-heading
           end-if
           if ws-line-consumed not = "Y"
               perform detect-horizontal-rule
           end-if
           if ws-line-consumed not = "Y"
               perform detect-list-item
           end-if
           if ws-line-consumed not = "Y"
               perform append-paragraph-line
           end-if.

       strip-blockquote-prefix.
           move 0 to ws-quote-depth
           move 1 to ws-content-start
           perform until ws-content-start > ws-next-length
               move ws-content-start to ws-j
               perform until ws-j > ws-next-length
                   or ws-j - ws-content-start >= 4
                   move ws-inner-line(ws-j:1) to ws-char
                   if ws-char = space
                       add 1 to ws-j
                   else
                       exit perform
                   end-if
               end-perform
               if ws-j > ws-next-length
                   exit perform
               end-if
               move ws-inner-line(ws-j:1) to ws-char
               if ws-char = ">"
                   add 1 to ws-quote-depth
                   add 1 to ws-j
                   move ws-j to ws-content-start
                   if ws-content-start <= ws-next-length
                       move ws-inner-line(ws-content-start:1) to ws-char
                       if ws-char = space
                           add 1 to ws-content-start
                       end-if
                   end-if
               else
                   exit perform
               end-if
           end-perform

           if ws-quote-depth not = ws-blockquote-depth
               perform close-paragraph
               perform close-code-block
               perform close-all-lists
               move ws-quote-depth to ws-target-depth
               perform adjust-blockquotes
           end-if

           move spaces to ws-item-text
           if ws-content-start <= ws-next-length
               move ws-inner-line(ws-content-start:
                   ws-next-length - ws-content-start + 1)
                   to ws-item-text
               move ws-item-text to ws-calc-text
               move 2048 to ws-calc-max
               perform calculate-length
               move ws-calc-length to ws-next-length
               move ws-item-text to ws-inner-line
           else
               move 0 to ws-next-length
               move spaces to ws-inner-line
           end-if.

       handle-code-line.
           perform count-leading-spaces
           if ws-next-length = 0
               move spaces to ws-output-line
               perform emit-line
               move "Y" to ws-line-consumed
           else
               if ws-indent >= 4
                   move spaces to ws-code-line
                   move ws-inner-line(5:ws-next-length - 4)
                       to ws-code-line
                   move ws-code-line to ws-source-text
                   move ws-code-line to ws-calc-text
                   move 2048 to ws-calc-max
                   perform calculate-length
                   move ws-calc-length to ws-source-length
                   perform escape-source-text
                   move ws-target-text to ws-output-line
                   perform emit-line
                   move "Y" to ws-line-consumed
               else
                   perform close-code-block
               end-if
           end-if.

       detect-code-block.
           perform count-leading-spaces
           if ws-indent >= 4
               perform close-paragraph
               perform close-all-lists
               perform open-code-block
               move spaces to ws-code-line
               move ws-inner-line(5:ws-next-length - 4) to ws-code-line
               move ws-code-line to ws-source-text
               move ws-code-line to ws-calc-text
               move 2048 to ws-calc-max
               perform calculate-length
               move ws-calc-length to ws-source-length
               perform escape-source-text
               move ws-target-text to ws-output-line
               perform emit-line
               move "Y" to ws-line-consumed
           end-if.

       detect-setext-heading.
           if ws-line-index >= ws-line-count
               exit paragraph
           end-if
           move ws-line-text(ws-line-index + 1) to ws-next-line
           move ws-line-length(ws-line-index + 1) to ws-work-length
           if ws-work-length = 0
               exit paragraph
           end-if
           move 0 to ws-heading-level
           move 0 to ws-meaningful-count
           move "Y" to ws-all-same
           move space to ws-hr-char
           perform varying ws-i from 1 by 1 until ws-i > ws-work-length
               move ws-next-line(ws-i:1) to ws-char
               if ws-char not = space
                   if ws-meaningful-count = 0
                       move ws-char to ws-hr-char
                   else
                       if ws-char not = ws-hr-char
                           move "N" to ws-all-same
                       end-if
                   end-if
                   add 1 to ws-meaningful-count
               end-if
           end-perform
           if ws-all-same = "Y" and ws-meaningful-count > 0
               if ws-hr-char = "="
                   move 1 to ws-heading-level
               end-if
               if ws-hr-char = "-"
                   move 2 to ws-heading-level
               end-if
           end-if
           if ws-heading-level > 0
               perform close-paragraph
               perform close-all-lists
               move ws-inner-line to ws-source-text
               move ws-next-length to ws-source-length
               perform convert-inline
               move ws-heading-level to ws-heading-text
               move spaces to ws-output-line
               string "<h" ws-heading-text ">"
                   delimited by size
                   ws-target-text(1:ws-target-length)
                   delimited by size
                   "</h" ws-heading-text ">"
                   delimited by size
                   into ws-output-line
               end-string
               perform emit-line
               move "Y" to ws-skip-next
               move "Y" to ws-line-consumed
           end-if.

       detect-atx-heading.
           perform count-leading-spaces
           if ws-indent > 3
               exit paragraph
           end-if
           move 0 to ws-heading-level
           compute ws-j = ws-indent + 1
           perform varying ws-i from ws-j by 1 until ws-i > ws-next-length
               move ws-inner-line(ws-i:1) to ws-char
               if ws-char = "#"
                   add 1 to ws-heading-level
               else
                   exit perform
               end-if
           end-perform
           if ws-heading-level < 1 or ws-heading-level > 6
               move 0 to ws-heading-level
               exit paragraph
           end-if
           if ws-i > ws-next-length
               move 0 to ws-heading-level
               exit paragraph
           end-if
           move ws-inner-line(ws-i:1) to ws-char
           if ws-char not = space
               move 0 to ws-heading-level
               exit paragraph
           end-if
           add 1 to ws-i
           move spaces to ws-item-text
           if ws-i <= ws-next-length
               move ws-inner-line(ws-i:ws-next-length - ws-i + 1)
                   to ws-item-text
           end-if
           perform strip-trailing-hashes
           move ws-item-text to ws-calc-text
           move 2048 to ws-calc-max
           perform calculate-length
           move ws-calc-length to ws-source-length
           move ws-item-text to ws-source-text
           perform close-paragraph
           perform close-all-lists
           perform convert-inline
           move ws-heading-level to ws-heading-text
           move spaces to ws-output-line
           string "<h" ws-heading-text ">"
               delimited by size
               ws-target-text(1:ws-target-length)
               delimited by size
               "</h" ws-heading-text ">"
               delimited by size
               into ws-output-line
           end-string
           perform emit-line
           move "Y" to ws-line-consumed.

       strip-trailing-hashes.
           move ws-item-text to ws-calc-text
           move 2048 to ws-calc-max
           perform calculate-length
           move ws-calc-length to ws-j
           perform until ws-j = 0
               move ws-item-text(ws-j:1) to ws-char
               if ws-char = "#"
                   move space to ws-item-text(ws-j:1)
                   subtract 1 from ws-j
               else
                   if ws-char = space
                       move space to ws-item-text(ws-j:1)
                       subtract 1 from ws-j
                   else
                       exit perform
                   end-if
               end-if
           end-perform.

       detect-horizontal-rule.
           move "Y" to ws-all-same
           move 0 to ws-meaningful-count
           move space to ws-hr-char
           perform varying ws-i from 1 by 1 until ws-i > ws-next-length
               move ws-inner-line(ws-i:1) to ws-char
               if ws-char not = space
                   if ws-meaningful-count = 0
                       move ws-char to ws-hr-char
                       if ws-char not = "-" and ws-char not = "*"
                           and ws-char not = "_"
                           move "N" to ws-all-same
                       end-if
                   else
                       if ws-char not = ws-hr-char
                           move "N" to ws-all-same
                       end-if
                   end-if
                   add 1 to ws-meaningful-count
               end-if
           end-perform
           if ws-all-same = "Y" and ws-meaningful-count >= 3
               perform close-paragraph
               perform close-all-lists
               move "<hr/>" to ws-output-line
               perform emit-line
               move "Y" to ws-line-consumed
           end-if.

       detect-list-item.
           perform count-leading-spaces
           move 0 to ws-list-marker-length
           move space to ws-current-list-type
           if ws-indent > 3 and ws-list-depth = 0
               exit paragraph
           end-if
           compute ws-j = ws-indent + 1
           if ws-j > ws-next-length
               exit paragraph
           end-if

           move ws-inner-line(ws-j:1) to ws-char
           if ws-char = "-" or ws-char = "*" or ws-char = "+"
               if ws-j < ws-next-length
                   move ws-inner-line(ws-j + 1:1) to ws-char-2
                   if ws-char-2 = space
                       move 2 to ws-list-marker-length
                       move "U" to ws-current-list-type
                   end-if
               end-if
           else
               move "N" to ws-digit-seen
               move 0 to ws-k
               perform varying ws-i from ws-j by 1 until ws-i > ws-next-length
                   move ws-inner-line(ws-i:1) to ws-char
                   if ws-char >= "0" and ws-char <= "9"
                       move "Y" to ws-digit-seen
                   else
                       if ws-char = "." and ws-digit-seen = "Y"
                           move ws-i to ws-k
                       end-if
                       exit perform
                   end-if
               end-perform
               if ws-k > 0 and ws-k < ws-next-length
                   move ws-inner-line(ws-k + 1:1) to ws-char-2
                   if ws-char-2 = space
                       compute ws-list-marker-length = ws-k - ws-j + 2
                       move "O" to ws-current-list-type
                   end-if
               end-if
           end-if

           if ws-list-marker-length > 0
               perform close-paragraph
               perform handle-list-item
               move "Y" to ws-line-consumed
           end-if.

       handle-list-item.
           move "N" to ws-close-current-li
           if ws-list-depth = 0
               perform open-list-level
           else
               if ws-indent > ws-stack-indent(ws-list-depth)
                   perform open-list-level
               else
                   perform until ws-list-depth = 0
                       if ws-indent < ws-stack-indent(ws-list-depth)
                           perform close-list-level
                       else
                           if ws-indent = ws-stack-indent(ws-list-depth)
                               if ws-current-list-type
                                   = ws-stack-type(ws-list-depth)
                                   move "Y" to ws-close-current-li
                                   exit perform
                               else
                                   perform close-list-level
                               end-if
                           else
                               move "Y" to ws-close-current-li
                               exit perform
                           end-if
                       end-if
                   end-perform
                   if ws-list-depth = 0
                       perform open-list-level
                   end-if
               end-if
           end-if

           if ws-close-current-li = "Y"
               if ws-stack-item-open(ws-list-depth) = "Y"
                   move "</li>" to ws-output-line
                   perform emit-line
                   move "N" to ws-stack-item-open(ws-list-depth)
               end-if
           end-if

           move spaces to ws-item-text
           compute ws-j = ws-indent + ws-list-marker-length + 1
           if ws-j <= ws-next-length
               move ws-inner-line(ws-j:ws-next-length - ws-j + 1)
                   to ws-item-text
           end-if
           move ws-item-text to ws-calc-text
           move 2048 to ws-calc-max
           perform calculate-length
           move ws-calc-length to ws-source-length
           move ws-item-text to ws-source-text
           perform convert-inline
           move spaces to ws-output-line
           move "<li>" to ws-output-line
           if ws-target-length > 0
               move ws-target-text(1:ws-target-length)
                   to ws-output-line(5:ws-target-length)
           end-if
           perform emit-line
           move "Y" to ws-stack-item-open(ws-list-depth).

       open-list-level.
           add 1 to ws-list-depth
           move ws-indent to ws-stack-indent(ws-list-depth)
           move ws-current-list-type to ws-stack-type(ws-list-depth)
           move "N" to ws-stack-item-open(ws-list-depth)
           if ws-current-list-type = "O"
               move "<ol>" to ws-output-line
           else
               move "<ul>" to ws-output-line
           end-if
           perform emit-line.

       close-list-level.
           if ws-stack-item-open(ws-list-depth) = "Y"
               move "</li>" to ws-output-line
               perform emit-line
           end-if
           if ws-stack-type(ws-list-depth) = "O"
               move "</ol>" to ws-output-line
           else
               move "</ul>" to ws-output-line
           end-if
           perform emit-line
           move 0 to ws-stack-indent(ws-list-depth)
           move space to ws-stack-type(ws-list-depth)
               ws-stack-item-open(ws-list-depth)
           subtract 1 from ws-list-depth.

       close-all-lists.
           perform until ws-list-depth = 0
               perform close-list-level
           end-perform.

       append-paragraph-line.
           if ws-paragraph-open not = "Y"
               move "Y" to ws-paragraph-open
               move spaces to ws-paragraph-buffer
           end-if
           move ws-inner-line to ws-item-text
           move "N" to ws-hard-break
           if ws-next-length > 0
               if ws-inner-line(ws-next-length:1) = "\"
                   move "Y" to ws-hard-break
                   move space to ws-item-text(ws-next-length:1)
               else
                   if ws-next-length > 1
                       if ws-inner-line(ws-next-length:1) = space
                           and ws-inner-line(ws-next-length - 1:1) = space
                           move "Y" to ws-hard-break
                           move space to ws-item-text(ws-next-length:1)
                           move space to ws-item-text(ws-next-length - 1:1)
                       end-if
                   end-if
               end-if
           end-if
           move ws-item-text to ws-calc-text
           move 2048 to ws-calc-max
           perform calculate-length
           move ws-calc-length to ws-source-length
           move ws-item-text to ws-source-text
           perform convert-inline

           move ws-paragraph-buffer to ws-calc-text
           move 16384 to ws-calc-max
           perform calculate-length
           move ws-calc-length to ws-j
           if ws-j > 0
               if ws-hard-break = "Y"
                   move "<br/>" to ws-paragraph-buffer(ws-j + 1:5)
                   add 5 to ws-j
               else
                   move " " to ws-paragraph-buffer(ws-j + 1:1)
                   add 1 to ws-j
               end-if
           end-if
           if ws-target-length > 0
               move ws-target-text(1:ws-target-length)
                   to ws-paragraph-buffer(ws-j + 1:ws-target-length)
           end-if
           move "Y" to ws-line-consumed.

       close-paragraph.
           if ws-paragraph-open = "Y"
               move ws-paragraph-buffer to ws-calc-text
               move 16384 to ws-calc-max
               perform calculate-length
               move spaces to ws-output-line
               move "<p>" to ws-output-line
               if ws-calc-length > 0
                   move ws-paragraph-buffer(1:ws-calc-length)
                       to ws-output-line(4:ws-calc-length)
               end-if
               move "</p>" to ws-output-line(ws-calc-length + 4:4)
               perform emit-line
               move "N" to ws-paragraph-open
               move spaces to ws-paragraph-buffer
           end-if.

       open-code-block.
           if ws-code-open not = "Y"
               move "Y" to ws-code-open
               move "<pre><code>" to ws-output-line
               perform emit-line
           end-if.

       close-code-block.
           if ws-code-open = "Y"
               move "</code></pre>" to ws-output-line
               perform emit-line
               move "N" to ws-code-open
           end-if.

       adjust-blockquotes.
           if ws-target-depth < ws-blockquote-depth
               perform until ws-target-depth = ws-blockquote-depth
                   move "</blockquote>" to ws-output-line
                   perform emit-line
                   subtract 1 from ws-blockquote-depth
               end-perform
           end-if
           if ws-target-depth > ws-blockquote-depth
               perform until ws-target-depth = ws-blockquote-depth
                   move "<blockquote>" to ws-output-line
                   perform emit-line
                   add 1 to ws-blockquote-depth
               end-perform
           end-if.

       count-leading-spaces.
           move 0 to ws-indent
           perform varying ws-i from 1 by 1 until ws-i > ws-next-length
               move ws-inner-line(ws-i:1) to ws-char
               if ws-char = space
                   add 1 to ws-indent
               else
                   exit perform
               end-if
           end-perform.

       convert-inline.
           move spaces to ws-target-text
           move 0 to ws-target-length
           move 1 to ws-inline-pos
           move "N" to ws-strong-open ws-em-open ws-code-span-open
           perform until ws-inline-pos > ws-source-length
               move ws-source-text(ws-inline-pos:1) to ws-char
               if ws-char = "\"
                   perform handle-inline-escape
               else
                   if ws-code-span-open = "Y"
                       if ws-char = "`"
                           move "</code>" to ws-segment-text
                           move 7 to ws-segment-length
                           perform append-segment
                           move "N" to ws-code-span-open
                           add 1 to ws-inline-pos
                       else
                           perform append-html-char
                           add 1 to ws-inline-pos
                       end-if
                   else
                       if ws-char = "`"
                           move "<code>" to ws-segment-text
                           move 6 to ws-segment-length
                           perform append-segment
                           move "Y" to ws-code-span-open
                           add 1 to ws-inline-pos
                       else
                           if ws-inline-pos < ws-source-length
                               move ws-source-text(ws-inline-pos + 1:1)
                                   to ws-char-2
                           else
                               move space to ws-char-2
                           end-if
                           if ws-char = "!" and ws-char-2 = "["
                               perform try-inline-image
                           else
                               if ws-char = "["
                                   perform try-inline-link
                               else
                                   if (ws-char = "*" or ws-char = "_")
                                       and ws-char-2 = ws-char
                                       perform toggle-strong
                                   else
                                       if ws-char = "*" or ws-char = "_"
                                           perform toggle-emphasis
                                       else
                                           perform append-html-char
                                           add 1 to ws-inline-pos
                                       end-if
                                   end-if
                               end-if
                           end-if
                       end-if
                   end-if
               end-if
           end-perform
           if ws-code-span-open = "Y"
               move "</code>" to ws-segment-text
               move 7 to ws-segment-length
               perform append-segment
           end-if
           if ws-em-open = "Y"
               move "</em>" to ws-segment-text
               move 5 to ws-segment-length
               perform append-segment
           end-if
           if ws-strong-open = "Y"
               move "</strong>" to ws-segment-text
               move 9 to ws-segment-length
               perform append-segment
           end-if.

       handle-inline-escape.
           if ws-inline-pos < ws-source-length
               add 1 to ws-inline-pos
               move ws-source-text(ws-inline-pos:1) to ws-char
               perform append-html-char
               add 1 to ws-inline-pos
           else
               add 1 to ws-inline-pos
           end-if.

       toggle-strong.
           if ws-strong-open = "Y"
               move "</strong>" to ws-segment-text
               move 9 to ws-segment-length
               move "N" to ws-strong-open
           else
               move "<strong>" to ws-segment-text
               move 8 to ws-segment-length
               move "Y" to ws-strong-open
           end-if
           perform append-segment
           add 2 to ws-inline-pos.

       toggle-emphasis.
           if ws-em-open = "Y"
               move "</em>" to ws-segment-text
               move 5 to ws-segment-length
               move "N" to ws-em-open
           else
               move "<em>" to ws-segment-text
               move 4 to ws-segment-length
               move "Y" to ws-em-open
           end-if
           perform append-segment
           add 1 to ws-inline-pos.

       try-inline-link.
           move spaces to ws-link-text ws-link-url
           move 0 to ws-link-text-length ws-link-url-length
           move ws-source-text to ws-source-backup
           move ws-source-length to ws-source-backup-length
           compute ws-j = ws-inline-pos + 1
           perform until ws-j > ws-source-length
               move ws-source-text(ws-j:1) to ws-char
               if ws-char = "]"
                   exit perform
               end-if
               add 1 to ws-link-text-length
               move ws-char to ws-link-text(ws-link-text-length:1)
               add 1 to ws-j
           end-perform
           if ws-j >= ws-source-length
               perform append-html-char
               add 1 to ws-inline-pos
               exit paragraph
           end-if
           if ws-source-text(ws-j + 1:1) not = "("
               perform append-html-char
               add 1 to ws-inline-pos
               exit paragraph
           end-if
           add 2 to ws-j
           perform until ws-j > ws-source-length
               move ws-source-text(ws-j:1) to ws-char
               if ws-char = ")"
                   exit perform
               end-if
               add 1 to ws-link-url-length
               move ws-char to ws-link-url(ws-link-url-length:1)
               add 1 to ws-j
           end-perform
           if ws-j > ws-source-length
               perform append-html-char
               add 1 to ws-inline-pos
               exit paragraph
           end-if

           move ws-j to ws-k
           move ws-target-text to ws-saved-target
           move ws-target-length to ws-saved-target-length

           move ws-link-url to ws-source-text
           move ws-link-url-length to ws-source-length
           perform escape-source-text
           move spaces to ws-temp-escaped-1
           if ws-target-length > 0
               move ws-target-text(1:ws-target-length)
                   to ws-temp-escaped-1(1:ws-target-length)
           end-if
           move ws-target-length to ws-temp-escaped-1-length

           move ws-link-text to ws-source-text
           move ws-link-text-length to ws-source-length
           perform escape-source-text
           move spaces to ws-temp-escaped-2
           if ws-target-length > 0
               move ws-target-text(1:ws-target-length)
                   to ws-temp-escaped-2(1:ws-target-length)
           end-if
           move ws-target-length to ws-temp-escaped-2-length

           move ws-saved-target to ws-target-text
           move ws-saved-target-length to ws-target-length

           move "<a href=""" to ws-segment-text
           move 9 to ws-segment-length
           perform append-segment
           if ws-temp-escaped-1-length > 0
               move ws-temp-escaped-1(1:ws-temp-escaped-1-length)
                   to ws-segment-text
               move ws-temp-escaped-1-length to ws-segment-length
               perform append-segment
           end-if
           move """>" to ws-segment-text
           move 2 to ws-segment-length
           perform append-segment
           if ws-temp-escaped-2-length > 0
               move ws-temp-escaped-2(1:ws-temp-escaped-2-length)
                   to ws-segment-text
               move ws-temp-escaped-2-length to ws-segment-length
               perform append-segment
           end-if
           move "</a>" to ws-segment-text
           move 4 to ws-segment-length
           perform append-segment
           move ws-source-backup to ws-source-text
           move ws-source-backup-length to ws-source-length
           compute ws-inline-pos = ws-k + 1.

       try-inline-image.
           move spaces to ws-image-alt ws-image-url
           move 0 to ws-image-alt-length ws-image-url-length
           move ws-source-text to ws-source-backup
           move ws-source-length to ws-source-backup-length
           compute ws-j = ws-inline-pos + 2
           perform until ws-j > ws-source-length
               move ws-source-text(ws-j:1) to ws-char
               if ws-char = "]"
                   exit perform
               end-if
               add 1 to ws-image-alt-length
               move ws-char to ws-image-alt(ws-image-alt-length:1)
               add 1 to ws-j
           end-perform
           if ws-j >= ws-source-length
               move "!" to ws-char
               perform append-html-char
               add 1 to ws-inline-pos
               exit paragraph
           end-if
           if ws-source-text(ws-j + 1:1) not = "("
               move "!" to ws-char
               perform append-html-char
               add 1 to ws-inline-pos
               exit paragraph
           end-if
           add 2 to ws-j
           perform until ws-j > ws-source-length
               move ws-source-text(ws-j:1) to ws-char
               if ws-char = ")"
                   exit perform
               end-if
               add 1 to ws-image-url-length
               move ws-char to ws-image-url(ws-image-url-length:1)
               add 1 to ws-j
           end-perform
           if ws-j > ws-source-length
               move "!" to ws-char
               perform append-html-char
               add 1 to ws-inline-pos
               exit paragraph
           end-if

           move ws-j to ws-k
           move ws-target-text to ws-saved-target
           move ws-target-length to ws-saved-target-length

           move ws-image-url to ws-source-text
           move ws-image-url-length to ws-source-length
           perform escape-source-text
           move spaces to ws-temp-escaped-1
           if ws-target-length > 0
               move ws-target-text(1:ws-target-length)
                   to ws-temp-escaped-1(1:ws-target-length)
           end-if
           move ws-target-length to ws-temp-escaped-1-length

           move ws-image-alt to ws-source-text
           move ws-image-alt-length to ws-source-length
           perform escape-source-text
           move spaces to ws-temp-escaped-2
           if ws-target-length > 0
               move ws-target-text(1:ws-target-length)
                   to ws-temp-escaped-2(1:ws-target-length)
           end-if
           move ws-target-length to ws-temp-escaped-2-length

           move ws-saved-target to ws-target-text
           move ws-saved-target-length to ws-target-length

           move "<img src=""" to ws-segment-text
           move 10 to ws-segment-length
           perform append-segment
           if ws-temp-escaped-1-length > 0
               move ws-temp-escaped-1(1:ws-temp-escaped-1-length)
                   to ws-segment-text
               move ws-temp-escaped-1-length to ws-segment-length
               perform append-segment
           end-if
           move """ alt=""" to ws-segment-text
           move 7 to ws-segment-length
           perform append-segment
           if ws-temp-escaped-2-length > 0
               move ws-temp-escaped-2(1:ws-temp-escaped-2-length)
                   to ws-segment-text
               move ws-temp-escaped-2-length to ws-segment-length
               perform append-segment
           end-if
           move """/>" to ws-segment-text
           move 3 to ws-segment-length
           perform append-segment
           move ws-source-backup to ws-source-text
           move ws-source-backup-length to ws-source-length
           compute ws-inline-pos = ws-k + 1.

       escape-source-text.
           move spaces to ws-target-text
           move 0 to ws-target-length
           perform varying ws-i from 1 by 1 until ws-i > ws-source-length
               move ws-source-text(ws-i:1) to ws-char
               perform append-html-char
           end-perform.

       append-html-char.
           evaluate ws-char
               when "&"
                   move "&amp;" to ws-segment-text
                   move 5 to ws-segment-length
               when "<"
                   move "&lt;" to ws-segment-text
                   move 4 to ws-segment-length
               when ">"
                   move "&gt;" to ws-segment-text
                   move 4 to ws-segment-length
               when """"
                   move "&quot;" to ws-segment-text
                   move 6 to ws-segment-length
               when other
                   move spaces to ws-segment-text
                   move ws-char to ws-segment-text(1:1)
                   move 1 to ws-segment-length
           end-evaluate
           perform append-segment.

       append-segment.
           if ws-segment-length > 0
               move ws-segment-text(1:ws-segment-length)
                   to ws-target-text(ws-target-length + 1:ws-segment-length)
               add ws-segment-length to ws-target-length
           end-if.

       emit-line.
           move ws-output-line to html-record
           write html-record.

       calculate-length.
           move ws-calc-max to ws-calc-length
           perform until ws-calc-length = 0
               move ws-calc-text(ws-calc-length:1) to ws-char
               if ws-char = space
                   subtract 1 from ws-calc-length
               else
                   exit perform
               end-if
           end-perform.
