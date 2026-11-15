#include "renderer.h"
#include <assert.h>
#include <stdlib.h>
static Uint32 pixel(SDL_Surface *s,int x,int y) {return ((Uint32 *)((char *)s->pixels+y*s->pitch))[x];}
static void clear(SDL_Surface *s,Uint8 a) {SDL_SetClipRect(s,NULL);SDL_FillRect(s,NULL,SDL_MapRGBA(s->format,32,33,37,a));}
int main(int argc,char **argv) {
  SDL_Surface *s=SDL_CreateRGBSurfaceWithFormat(0,80,64,32,SDL_PIXELFORMAT_BGRA32);
  RenSurface rs={s,1};RenColor gold={7,193,255,255};
  clear(s,255);Uint32 bg=pixel(s,0,0);
  ren_draw_rounded_rect(&rs,4,4,24,20,7,gold);
  Uint32 full=SDL_MapRGBA(s->format,255,193,7,255);
  assert(pixel(s,16,14)==full && pixel(s,4,4)==bg);
  int partial=0;
  for(int y=0;y<20;y++)for(int x=0;x<24;x++) {
    Uint32 p=pixel(s,4+x,4+y);
    assert(p==pixel(s,4+23-x,4+y) && p==pixel(s,4+x,4+19-y));
    if(p!=bg && p!=full)partial++;
  }
  assert(partial>=8);
  clear(s,255);ren_draw_rounded_rect(&rs,4.25,3.75,23.5,19.5,6.5,gold);
  assert(pixel(s,0,0)==bg && pixel(s,15,13)==full);
  clear(s,255);rs.scale=2;ren_draw_rounded_rect(&rs,4,4,24,20,7,gold);
  assert(pixel(s,32,28)==full && pixel(s,8,8)==bg);
  clear(s,255);rs.scale=1;SDL_Rect clip={12,12,4,4};SDL_SetClipRect(s,&clip);
  ren_draw_rounded_rect(&rs,4,4,24,20,7,gold);
  assert(pixel(s,12,12)==full && pixel(s,11,12)==bg);
  clear(s,0);gold.a=128;ren_draw_rounded_rect(&rs,4,4,24,20,7,gold);
  Uint8 r,g,b,a;SDL_GetRGBA(pixel(s,16,14),s->format,&r,&g,&b,&a);
  assert(r==255 && g==193 && b==7 && a==128);
  clear(s,255);ren_draw_rounded_rect(&rs,4,4,24,20,7,gold);
  SDL_GetRGBA(pixel(s,16,14),s->format,&r,&g,&b,&a);
  assert(abs(r-144)<=1 && abs(g-113)<=1 && abs(b-22)<=1 && a==255);
  SDL_FreeSurface(s);
  if(argc>1) {
    s=SDL_CreateRGBSurfaceWithFormat(0,1440,224,32,SDL_PIXELFORMAT_BGRA32);clear(s,255);rs.surface=s;
    int widths[]={60,74,108,84,156,90,84};
    for(int scale=1;scale<=2;scale++) {
      rs.scale=scale;int x=12;
      for(int i=0;i<7;i++) {
        RenColor c=i==0?(RenColor){7,193,255,255}:(RenColor){58,55,52,255};
        ren_draw_rounded_rect(&rs,x,scale==1?40:64,widths[i],32,6,c);x+=widths[i]+5;
      }
    }
    assert(SDL_SaveBMP(s,argv[1])==0);SDL_FreeSurface(s);
  }
  return 0;
}
