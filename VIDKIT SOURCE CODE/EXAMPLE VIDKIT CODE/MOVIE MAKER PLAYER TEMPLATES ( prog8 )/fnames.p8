%encoding iso
%import strings


fnames {

str PATH = "?" * 128
ubyte PLength
str NAME = "?" * 80
ubyte NLength
str EXT = "?" * 10
ubyte ELength


sub parse(str tFile) {
ubyte L
ubyte extP
ubyte nameP
ubyte pathP
ubyte curP
bool done

   PATH[0] = 0
   NAME[0] = 0
   EXT[0] = 0
   extP = 0
   nameP = 0
   pathP = 0
   curP = 0
   L = strings.length(tFile)
   if L>0 { curP = L-1 }
   done = (L==0)
   while not done {
     if extP == 0 {
        if tFile[curP] == '.' { extP = curP }
     }
     if pathP==0 {
        if tFile[curP] == '/' {
           pathP=curP
           nameP=curP+1
           done=true
        }
     }
     if not done {
        done = (curP==0)
        if not done { curP-- }
     }
   }
   if extP > 0 {
      strings.right(tFile,L-extP,EXT)
   }
   if pathP > 0 {
      strings.left(tFile,pathP+1,PATH)
      pathP++
   }
   PLength = strings.length(PATH)
   ELength = strings.length(EXT)
   strings.slice(tFile,PLength,(L -ELength)-PLength,NAME)
   NLength = strings.length(NAME)
}

}
