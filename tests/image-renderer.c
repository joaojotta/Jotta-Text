#include "image.h"
#include <glib.h>
#include <assert.h>
#include <stdio.h>
static void white(SDL_Surface *surface) { SDL_FillRect(surface,NULL,SDL_MapRGBA(surface->format,255,255,255,255)); }
static void check(SDL_Surface *surface,int x,int y,int red,int green,int blue) {
  Uint32 pixel=((Uint32 *)((char *)surface->pixels+y*surface->pitch))[x];
  Uint8 r,g,b,a;SDL_GetRGBA(pixel,surface->format,&r,&g,&b,&a);
  assert(abs(r-red)<=1 && abs(g-green)<=1 && abs(b-blue)<=1 && a==255);
}
int main(int argc,char **argv) {
  assert(argc==2);
  char *error=NULL;RenImage *image=ren_image_load(argv[1],&error);
  if (!image) {fprintf(stderr,"%s\n",error);g_free(error);return 1;}
  SDL_Surface *target=SDL_CreateRGBSurfaceWithFormat(0,20,20,32,SDL_PIXELFORMAT_BGRA32);
  RenSurface surface={target,1};white(target);
  SDL_Rect clip={4,2,3,3};SDL_SetClipRect(target,&clip);
  ren_draw_image(&surface,image,(RenRect){2,1,8,6});
  check(target,4,2,248,173,144);check(target,3,2,255,255,255);
  SDL_SetClipRect(target,NULL);white(target);surface.scale=2;
  ren_draw_image(&surface,image,(RenRect){1,1,4,3});
  check(target,2,2,248,173,144);check(target,1,1,255,255,255);
  white(target);surface.scale=1;
  ren_draw_image(&surface,image,(RenRect){-999990,-999990,1000000,1000000});
  check(target,0,0,248,173,144);check(target,10,10,255,255,255);
  ren_image_free(image);SDL_FreeSurface(target);return 0;
}
