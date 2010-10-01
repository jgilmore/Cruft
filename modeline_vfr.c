/***************************************************************
*
* Modeline Tool
*
* Andreas Bohne / 1998 / http://www.dkfz-heidelberg.de/spec/
*
* Use on your own risk.
*
* Input:  Resolution and  Vertical Frequence
* Output: Modeline
*
* Example use:
* <modline> 640 480 75 
* (640x480 with a vert. frequence of 75 hz)
*
* Distributed by GNU Public Licence (GPL) 
*/

#include<stdio.h>
#include<stdlib.h>

int
main( int argc, char** argv )
{
	float		hr,vr;
	float		dcf;
	float		rr,hsf,vtick;
	float		hfront,hsync,hblank,hfl,vfront,vsync,vback,vblank,vfl;
	
	const	float	hfrontmin	= 0.50;
	const   float   hsyncmin	= 1.20;
	const   float   hbackmin	= 1.25;
	const   float   hblankmin	= 4.00;
	const   float   hsfmax		= 60.0;

	const   float   vfrontmin 	= 0.0;
	const   float   vsyncmin	= 45.0;
	const   float   vbackmin	= 500.0;
	const   float   vblankmin	= 600.0;
	const   float   vsfmax 		= 90.0;

	int    	ende = 0;
	int 	v1,v2;
	float	step =10.0;
	float 	s_rr;
	if(argc != 4)
	{
		puts("usage: modeline Hsize Vsize Vrefresh");
		exit(1);
	}

        sscanf(argv[1],"%f",&hr);
        sscanf(argv[2],"%f",&vr);
        sscanf(argv[3],"%f",&s_rr);

	if(s_rr<20.0) s_rr =20.0;
	dcf = 1.0;

do{
	rr = 1000000.0 * dcf / (hfl * vfl);
	hsf = 1000.0 * dcf / hfl;

	hfront = hfrontmin * dcf + hr;
	if( (int)(hfront) % 8 ) hfront = 8 * (1 + (float)((int)(hfront/8)));

	hsync = hsyncmin * dcf + hfront;
	if( (int)(hsync)%8) hsync = 8 * (1+ (float)((int)(hsync/8)));

	hblank = hblankmin * dcf;
	hfl = hr + hblank;
	if((int)(hfl)%8) hfl = 8 * (1+(float)((int)(hfl/8)));

	vtick = hfl / dcf;
	vfront = vr + vfrontmin / vtick;

	vsync = vfront + vsyncmin /vtick;
	vback = vbackmin /vtick;
	vblank = vblankmin / vtick;
	
	vfl = vsync + vback;
	if( vfl < vr+ vblank) vfl = vr + vblank;

	v1 = (int)(rr*1000.0);
	v2 = (int)(s_rr*1000.0);

	if( v1 == v2 ) ende =1;
	else if( v1 < v2 ) dcf += step;
	else if( v1 > v2 ) { dcf -= step; step /= 10.0 ;}

} while( !ende);

	printf("  Horizontal Resolution:   %4.0f \n",hr);
	printf("  Vertical Resolution:     %4.0f \n",vr);
	printf("  Vertical Refresh Rate:   %4.2f Hz \n",rr);
	printf("  Horizontal Refresh Rate: %4.2f KHz \n",hsf);
	printf("  Dot Clock Frequence:     %4.2f MHz \n",dcf);
	printf("\n");
	printf(" # V-freq: %4.2f Hz  // h-freq: %4.2f KHz\n Modeline \"%dx%d\" %4.2f  %4d %4d %4d %4d  %4d %4d %4d %4d \n",rr,hsf,(int)(hr),(int)(vr),(dcf),(int)(hr),(int)(hfront),(int)(hsync),(int)(hfl),(int)(vr),(int)(vfront),(int)(vsync),(int)(vfl));
	
	exit(0);
}
	
	 
	
	
	
		
