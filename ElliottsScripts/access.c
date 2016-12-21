#include <unistd.h>
#include <stdio.h>

int main () {
   int readable;
   readable = access("./mount/testfile", R_OK);
   if (readable == -1)
       printf("Not readable!\n");
   else
       printf("Readable!\n");

   return 0;
}
