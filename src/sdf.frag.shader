mat3 calculateEyeRayTransformationMatrix( in vec3 ro, in vec3 ta, in float roll )
{
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(sin(roll),cos(roll),0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
    return mat3( uu, vv, ww );
}



vec2 sdfBalloon( vec3 currentRayPosition ){
  
  // First we define our balloon position
  vec3 balloonPosition = vec3( .3 , .3 , -0.4 );
    
  // than we define our balloon radius
  float balloonRadius = 1.1 + sin( iTime );
    
  // Here we get the distance to the surface of the balloon
  float distanceToBalloon = length( currentRayPosition - balloonPosition );
    
  // finally we get the distance to the balloon surface
  // by substacting the balloon radius. This means that if
  // the distance to the balloon is less than the balloon radius
  // the value we get will be negative! giving us the 'Signed' in
  // Signed Distance Field!
  float distanceToBalloonSurface = distanceToBalloon - balloonRadius;
    
  
  // Finally we build the full balloon information, by giving it an ID
  float balloonID = 1.;
    	
  // And there we have it! A fully described balloon!
  vec2 balloon = vec2( distanceToBalloonSurface,  balloonID );
    
  return balloon;
    
}


vec2 sdfBox( vec3 currentRayPosition ){
  
  // First we define our box position
  vec3 boxPosition = vec3( -.8 , -.4 + cos( 1.241214*iTime ) , 0.2 );
    
  // than we define our box dimensions using x , y and z
  vec3 boxSize = vec3( .4 , .3 , .2 );
    
  // Here we get the 'adjusted ray position' which is just
  // writing the point of the ray as if the origin of the 
  // space was where the box was positioned, instead of
  // at 0,0,0 . AKA the difference between the vectors in
  // vector format.
  vec3 adjustedRayPosition = currentRayPosition - boxPosition;
    
  // finally we get the distance to the box surface.
  // I don't get this part very much, but I bet Inigo does!
  // Thanks for making code for us IQ !
  vec3 distanceVec = abs( adjustedRayPosition ) - boxSize;
  float maxDistance = max( distanceVec.x , max( distanceVec.y , distanceVec.z ) ); 
  float distanceToBoxSurface = min( maxDistance , 0.0 ) + length( max( distanceVec , 0.0 ) );
  
  // Finally we build the full box information, by giving it an ID
  float boxID = 2.;
    	
  // And there we have it! A fully described box!
  vec2 box = vec2( distanceToBoxSurface,  boxID );
    
  return box;
    
}


// 'TAG : WHICH AM I CLOSER TO?'
// This function takes in two things
// and says which is closer by using the 
// distance to each thing, comparing them
// and returning the one that is closer!
vec2 whichThingAmICloserTo( vec2 thing1 , vec2 thing2 ){
 
   vec2 closestThing;
    
   // Check out the balloon function
   // and remember how the x of the returned
   // information is the distance, and the y 
   // is the id of the thing!
   if( thing1.x <= thing2.x ){
       
   	   closestThing = thing1;
       
   }else if( thing2.x < thing1.x ){
       
       closestThing = thing2;
       
   }
 
   return closestThing;
    
}

    

// Takes in the position of the ray, and feeds back
// 2 values of how close it is to things in the world
// what thing it is closest two in the world.
vec2 mapTheWorld( vec3 currentRayPosition, int ignoreId ){


  vec2 result;
 
    
  vec2 balloon = sdfBalloon( currentRayPosition );
  vec2 box     = sdfBox( currentRayPosition );
    
  if( ignoreId == 1 ) {
    result = box;
  }else if( ignoreId == 2 ) {
    result = balloon;
  }else { 
    result = whichThingAmICloserTo( balloon , box );
  }
    
  return result;


}



//---------------------------------------------------
// SECTION 'C' : NAVIGATING THE WORLD
//---------------------------------------------------

// We want to know when the closeness to things in the world is
// 0.0 , but if we wanted to get exactly to 0 it would take us
// alot of time to be that precise. Here we define the laziness
// our navigation function. try chaning the value to see what it does!
// if you are getting too low of framerates, this value will help alot,
// but can also make your scene look very different
// from how it should
const float HOW_CLOSE_IS_CLOSE_ENOUGH = 0.001;

// This is basically how big our scene is. each ray will be shot forward
// until it reaches this distance. the smaller it is, the quicker the 
// ray will reach the edge, which should help speed up this function
const float FURTHEST_OUR_RAY_CAN_REACH = 10.;

// This is how may steps our ray can take. Hopefully for this
// simple of a world, it will very quickly get to the 'close enough' value
// and stop the iteration, but for more complex scenes, this value
// will dramatically change not only how good the scene looks
// but how fast teh scene can render. 

// remember that for each pixel we are displaying, the 'mapTheWorld' function
// could be called this many times! Thats ALOT of calculations!!!
const int HOW_MANY_STEPS_CAN_OUR_RAY_TAKE = 100;


vec2 checkRayHit( in vec3 eyePosition , in vec3 rayDirection, int ignoreId ){
  //First we set some default values
 
  
  // our distance to surface will get overwritten every step,
  // so all that is important is that it is greater than our
  // 'how close is close enough' value
  float distanceToSurface 			= HOW_CLOSE_IS_CLOSE_ENOUGH * 2.;
    
  // The total distance traveled by the ray obviously should start at 0
  float totalDistanceTraveledByRay 	= 0.;
    
  // if we hit something, this value will be overwritten by the
  // totalDistance traveled, and if we don't hit something it will
  // be overwritten by the furthest our ray can reach,
  // so it can be whatever!
  float finalDistanceTraveledByRay 	= -1.;
    
  // if our id is less that 0. , it means we haven't hit anything
  // so lets start by saying we haven't hit anything!
  float finalID = -1.;

    
    
  //here is the loop where the magic happens
  for( int i = 0; i < HOW_MANY_STEPS_CAN_OUR_RAY_TAKE; i++ ){
      
    // First off, stop the iteration, if we are close enough to the surface!
    if( distanceToSurface < HOW_CLOSE_IS_CLOSE_ENOUGH ) break;
      
    // Second off, stop the iteration, if we have reached the end of our scene! 
    if( totalDistanceTraveledByRay > FURTHEST_OUR_RAY_CAN_REACH ) break;
    
    // To check how close we are to things in the world,
    // we need to get a position in the scene. to do this, 
    // we start at the rays origin, AKA the eye
    // and move along the ray direction, the amount we have already traveled.
    vec3 currentPositionOfRay = eyePosition + rayDirection * totalDistanceTraveledByRay;
    
    // Distance to and ID of things in the world
    //--------------------------------------------------------------
	// SECTION 'D' : MAPPING THE WORLD , AKA 'SDFS ARE AWESOME!!!!'
	//--------------------------------------------------------------
    vec2 distanceAndIDOfThingsInTheWorld = mapTheWorld( currentPositionOfRay, ignoreId );
      
      
 	// we get out the results from our mapping of the world
    // I am reassigning them for clarity
    float distanceToThingsInTheWorld = distanceAndIDOfThingsInTheWorld.x;
    float idOfClosestThingInTheWorld = distanceAndIDOfThingsInTheWorld.y;
     
    // We save out the distance to the surface, so that
    // next iteration we can check to see if we are close enough 
    // to stop all this silly iteration
    distanceToSurface           = distanceToThingsInTheWorld;
      
    // We are also finalID to the current closest id,
    // because if we hit something, we will have the proper
    // id, and we can skip reassigning it later!
    finalID = idOfClosestThingInTheWorld;  
     
    // ATTENTION: THIS THING IS AWESOME!
   	// This last little calculation is probably the coolest hack
    // of this entire tutorial. If we wanted too, we could basically 
    // step through the field at a constant amount, and at every step
    // say 'am i there yet', than move forward a little bit, and
    // say 'am i there yet', than move forward a little bit, and
    // say 'am i there yet', than move forward a little bit, and
    // say 'am i there yet', than move forward a little bit, and
    // say 'am i there yet', than move forward a little bit, and
    // that would take FOREVER, and get really annoying.
      
    // Instead what we say is 'How far until we are there?'
    // and move forward by that amount. This means that if
    // we are really far away from everything, we can make large
    // movements towards the surface, and if we are closer
    // we can make more precise movements. making our marching functino
    // faster, and ideally more precise!!
      
    // WOW!
      
    totalDistanceTraveledByRay += distanceToThingsInTheWorld;
      

  }

  // if we hit something set the finalDirastnce traveled by
  // ray to that distance!
  if( totalDistanceTraveledByRay < FURTHEST_OUR_RAY_CAN_REACH ){
  	finalDistanceTraveledByRay = totalDistanceTraveledByRay;
  }
    
    
  // If the total distance traveled by the ray is further than
  // the ray can reach, that means that we've hit the edge of the scene
  // Set the final distance to be the edge of the scene
  // and the id to -1 to make sure we know we haven't hit anything
  if( totalDistanceTraveledByRay > FURTHEST_OUR_RAY_CAN_REACH ){ 
  	finalDistanceTraveledByRay = FURTHEST_OUR_RAY_CAN_REACH;
    finalID = -1.;
  }

  return vec2( finalDistanceTraveledByRay , finalID ); 

}







//--------------------------------------------------------------
// SECTION 'E' : COLORING THE WORLD
//--------------------------------------------------------------



// Here we are calcuting the normal of the surface
// Although it looks like alot of code, it actually
// is just trying to do something very simple, which
// is to figure out in what direction the SDF is increasing.
// What is amazing, is that this value is the same thing 
// as telling you what direction the surface faces, AKA the
// normal of the surface. 
vec3 getNormalOfSurface( in vec3 positionOfHit, int ignoreId ){
    
	vec3 tinyChangeX = vec3( 0.001, 0.0, 0.0 );
    vec3 tinyChangeY = vec3( 0.0 , 0.001 , 0.0 );
    vec3 tinyChangeZ = vec3( 0.0 , 0.0 , 0.001 );
    
   	float upTinyChangeInX   = mapTheWorld( positionOfHit + tinyChangeX, ignoreId ).x; 
    float downTinyChangeInX = mapTheWorld( positionOfHit - tinyChangeX, ignoreId ).x; 
    
    float tinyChangeInX = upTinyChangeInX - downTinyChangeInX;
    
    
    float upTinyChangeInY   = mapTheWorld( positionOfHit + tinyChangeY, ignoreId ).x; 
    float downTinyChangeInY = mapTheWorld( positionOfHit - tinyChangeY, ignoreId ).x; 
    
    float tinyChangeInY = upTinyChangeInY - downTinyChangeInY;
    
    
    float upTinyChangeInZ   = mapTheWorld( positionOfHit + tinyChangeZ, ignoreId ).x; 
    float downTinyChangeInZ = mapTheWorld( positionOfHit - tinyChangeZ, ignoreId ).x; 
    
    float tinyChangeInZ = upTinyChangeInZ - downTinyChangeInZ;
    
    
	vec3 normal = vec3(
         			tinyChangeInX,
        			tinyChangeInY,
        			tinyChangeInZ
    	 		  );
    
	return normalize(normal);
}





// doing our background color is easy enough,
// just make it pure black. like my soul.
vec3 doBackgroundColor(){
	return vec3( 0. );
}




vec3 doBalloonColor(vec3 positionOfHit , vec3 normalOfSurface ){
    
    vec3 sunPosition = vec3( 1. , 4. , 3. );
    
    // the direction of the light goes from the sun
    // to the position of the hit
    vec3 lightDirection = sunPosition - positionOfHit;
   	
    
    // Here we are 'normalizing' the light direction
   	// because we don't care how long it is, we
    // only care what direction it is!
    lightDirection = normalize( lightDirection );
    
    
    // getting the value of how much the surface
    // faces the light direction
    float faceValue = dot( lightDirection , normalOfSurface );
	
    // if the face value is negative, just make it 0.
    // so it doesn't give back negative light values
    // cuz that doesn't really make sense...
    faceValue = max( 0. , faceValue );
    
    vec3 balloonColor = vec3( 1. , 0. , 0. );
    
   	// our final color is the balloon color multiplied
    // by how much the surface faces the light
    vec3 color = balloonColor * faceValue;
    
    // add in a bit of ambient color
    // just so we don't get any pure black
    color += vec3( .3 , .1, .2 );
    
    
	return color;
}



// Here we are using the normal of the surface,
// and mapping it to color, to show you just how cool
// normals can be!
vec3 doBoxColor(vec3 positionOfHit , vec3 normalOfSurface ){
    
    vec3 color = vec3( normalOfSurface.x , normalOfSurface.y , normalOfSurface.z );
    
    //could also just write color = normalOfSurce
    //but trying to be explicit.
    
	return color;
}




// This is where we decide
// what color the world will be!
// and what marvelous colors it will be!
vec3 colorTheWorld( vec2 rayHitInfo , vec3 eyePosition , vec3 rayDirection, int ignoreId ){
   
  // remember for color
  // x = red , y = green , z = blue
  vec3 color;
    
  // THE LIL RAY WENT ALL THE WAY
  // TO THE EDGE OF THE WORLD, 
  // AND DIDN'T HIT ANYTHING
  if( rayHitInfo.y < 0.0 ){
      
  	color = doBackgroundColor();  
     
      
  // THE LIL RAY HIT SOMETHING!!!!
  }else{
      
      // If we hit something, 
      // we also know how far the ray has to travel to hit it
      // and because we know the direction of the ray, we can
      // get the exact position of where we hit the surface
      // by following the ray from the eye, along its direction
      // for the however far it had to travel to hit something
      vec3 positionOfHit = eyePosition + rayHitInfo.x * rayDirection;
      
      // We can then use this information to tell what direction
      // the surface faces in
      vec3 normalOfSurface = getNormalOfSurface( positionOfHit, ignoreId );
      
      
      // 1.0 is the Balloon ID
      if( rayHitInfo.y == 1.0 ){
          
  		color = doBalloonColor( positionOfHit , normalOfSurface ); 
       
          
      // 2.0 is the Box ID
      }else if( rayHitInfo.y == 2.0 ){
          
      	color = doBoxColor( positionOfHit , normalOfSurface );   
          
      }
 
  
  }
    
    
    return color;
    
    
}



void main( out vec4 fragColor, in vec2 fragCoord )
{
    
    //---------------------------------------------------
    // SECTION 'A' : ONE PROGRAM FOR EVERY PIXEL!
    //---------------------------------------------------
    
    // Here we are getting our 'Position' of each pixel
    // This section is important, because if we didn't
    // divied by the resolution, our values would be masssive
    // as fragCoord returns the value of how many pixels over we 
    // are. which is alot :)
	vec2 p = ( -iResolution.xy + 2.0 * fragCoord.xy ) / iResolution.y;
     
    // thats a super long name, so maybe we will 
    // keep on using uv, but im explicitly defining it
    // so you can see exactly what those two letters mean
    vec2 xyPositionOfPixelInWindow = p;
    
    
    
    //---------------------------------------------------
    // SECTION 'B' : BUILDING THE WINDOW
    //---------------------------------------------------
    
    // We use the eye position to tell use where the viewer is
    vec3 eyePosition = vec3( 0., 0., 2.);
    
    // This is the point the view is looking at. 
    // The window will be placed between the eye, and the 
    // position the eye is looking at!
    vec3 pointWeAreLookingAt = vec3( 0. , 0. , 0. );
  
	// This is where the magic of actual mathematics
    // gives a way to actually place the window.
    // the 0. at the end there gives the 'roll' of the transformation
    // AKA we would be standing so up is up, but up could be changing 
    // like if we were one of those creepy dolls whos rotate their head
    // all the way around along the z axis
    mat3 eyeTransformationMatrix = calculateEyeRayTransformationMatrix( eyePosition , pointWeAreLookingAt , 0. ); 
   
    
    // Here we get the actual ray that goes out of the eye
    // and through the individual pixel! This basically the only thing
    // that is different between the pixels, but is also the bread and butter
    // of ray tracing. It should be since it has the word 'ray' in its variable name...
    // the 2. at the end is the 'lens length' . I don't know how to best
    // describe this, but once the full scene is built, tryin playing with it
    // to understand inherently how it works
    vec3 rayComingOutOfEyeDirection = normalize( eyeTransformationMatrix * vec3( p.xy , 2. ) ); 

    
    
    //---------------------------------------------------
	// SECTION 'C' : NAVIGATING THE WORLD
	//---------------------------------------------------
    vec2 rayHitInfo = checkRayHit( eyePosition , rayComingOutOfEyeDirection, -1 );
    
    vec2 secondHit = checkRayHit( eyePosition, rayComingOutOfEyeDirection, int( rayHitInfo.y ) );
    
    
    //--------------------------------------------------------------
	// SECTION 'E' : COLORING THE WORLD
	//--------------------------------------------------------------
	vec3 color = colorTheWorld( rayHitInfo , eyePosition , rayComingOutOfEyeDirection, -1);
	vec3 color2 = colorTheWorld( secondHit , eyePosition , rayComingOutOfEyeDirection, int( rayHitInfo.y ) );
    
   
   	//--------------------------------------------------------------
    // SECTION 'F' : Wrapping up
    //--------------------------------------------------------------
	fragColor = vec4(0.1*(9.0*color+color2),1.0);
    
    
    // WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW!
    // WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! 
    // WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! 
    // WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! 
    // WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! WOW! 
    
    
}

