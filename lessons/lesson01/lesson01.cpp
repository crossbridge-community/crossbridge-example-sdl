#include "SDL/SDL.h"

#ifdef __AVM2__
    #include <AS3/AS3.h>
#endif

SDL_Rect screenRect;

SDL_Surface* hello = NULL;
SDL_Surface* screen = NULL;

//The attributes of the screen
const int SCREEN_WIDTH = 640;
const int SCREEN_HEIGHT = 480;
const int SCREEN_BPP = 32;

void draw()
{
    printf("%s\n", "Draw" );
    //Apply image to screen
    SDL_BlitSurface( hello, NULL, screen, NULL );
    //Update Screen
    SDL_Flip( screen );
    //SDL_UpdateRects(screen, 1, &screenRect);  
    // SDL_Delay(20);
}


int main( int argc, char* args[] )
{
    printf("%s\n", "Main" );

    screenRect.x = 0;
    screenRect.y = 0;
    screenRect.w = SCREEN_WIDTH; 
    screenRect.h = SCREEN_HEIGHT;

    //Start SDL
    SDL_Init( SDL_INIT_VIDEO);

    //Set up screen
    screen = SDL_SetVideoMode( SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_BPP, SDL_SWSURFACE );

    //Load image
    hello = SDL_LoadBMP( "/hello.bmp" );

    if (hello == NULL)
    {
        printf("Load failed: %s\n", SDL_GetError());
    }
    else
    {
        printf("Load success\n" );
    }

    // drawing bitmap on the screen
    draw();

    #ifdef __AVM2__
        AS3_GoAsync();
        return 0;
    #endif

    //Wait 5 seconds
    SDL_Delay( 5000 );

    //Free the loaded image
    SDL_FreeSurface( hello );

    //Quit SDL
    SDL_Quit();

    return 0;
}
