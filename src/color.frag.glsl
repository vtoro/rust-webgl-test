#version 100
precision highp float;

uniform vec3 iResolution;
uniform float iTime;
const int max_steps = 64;
const float max_depth = 200000000.0;
const float min_distance = 0.01;
const vec3 sun_dir = normalize(vec3( 20.0,40.0,-10.0 ));

struct sdf {
    int type;
    vec3 position;
    vec3 features;
    vec3 color;
};

struct hit {
    vec3 hit_position;
    int hit_object;
    float distance;
};

struct ray {
    vec3 position;
    vec3 direction;
    float length;
    int ignore_object;
};

ray rayfwd( ray r, float by ) {
    r.position = r.position + r.direction * by;
    r.length = r.length + by;
    return r;
}

const int worldsdfslength = 6;
sdf worldsdfs(int i) {
    if( i == 0 ) {
        return sdf( 1, vec3( 0.0, 0.0, 0.0 ), vec3( 0.1, 0.0, 0.0 ), vec3( 1.0, 0.0, 0.0 ) );
    }
    if( i == 1 ) {
        return sdf( 101, vec3( -2.8, -2.0, -2.3 + sin(iTime*0.6) * 3.0 ), vec3( 2.6, 0.0, 0.0 ), vec3( 1.0, 1.0, 0.5 ) );
    }
    if( i == 2 ) {
        return sdf( 100, vec3( 0.5 + sin( iTime * 0.7 ), 1.0, 0.0 ), vec3( 0.4, 0.0, 0.0 ), vec3( 0.5, 1.0, 0.5 ) );
    }
    if( i == 3 ) {
        return sdf( 1, vec3(-3.0, 1.0*cos(iTime*0.8)*1.0, 1.0 ), vec3( 1.0, 0.0, 0.0 ), vec3( 0.0, 0.0, 1.0 ) );
    }
    if( i == 4 ) {
        return sdf( 0, vec3(-5.0, .0,-3.0 ), vec3( 1.0, 0,0  ), vec3( 1.0, abs(sin( iTime * .6)), 1.0 ) );  
    }
    if( i == 5 ) {
        return sdf( 2, vec3( 0.0,-3.0, 0.0 ), vec3( 1.0, 0.0, 0.0 ), vec3( 1.0, 0.0, 1.0 ) );
    }
}


hit sdf_cube( vec3 ray_pos, vec3 cube_pos, float size, int itemId ) {
    return hit( 
        ray_pos,
        itemId, 
        max( 
            abs(ray_pos.x - cube_pos.x) - size, 
            max( 
                abs(ray_pos.y - cube_pos.y) - size, 
                abs(ray_pos.z - cube_pos.z) - size
            ) 
        )
    );
}

hit sdf_circle(vec3 ray_pos, vec3 cube_pos, float size, int itemId) 
{
    return hit( ray_pos, itemId, length( cube_pos - ray_pos) - size );
}

hit sdf_ground( vec3 ray_pos, int itemId ) {
    return hit( ray_pos, itemId, ray_pos.y + 2.0 );
}

hit hit_sdf( ray r, sdf s, int object_id ) {
    if( s.type == 0 ) { 
        return sdf_cube( r.position, s.position, s.features.x, object_id );
    }
    if( s.type == 1 ) { 
        return sdf_circle( r.position, s.position, s.features.x, object_id );
    }
    if( s.type == 2 ) { 
        return sdf_ground( r.position, object_id );
    }
    if( s.type == 100 ) { 
        return sdf_cube( r.position, s.position, s.features.x, object_id );
    }
    if( s.type == 101 ) { 
        return sdf_circle( r.position, s.position, s.features.x, object_id );
    }
}


hit closest( hit obj1, hit obj2 ) {
    if( obj1.distance > obj2.distance ) {
        return obj2;
    } else {
        return obj1;
    }

}

hit world( ray r ) {
    hit h = hit_sdf( r, worldsdfs(r.ignore_object == 0 ? 1 : 0), 0 );
    for( int i=1; i < worldsdfslength; i++ ) {
        if( i == r.ignore_object ) continue;
        hit n = hit_sdf( r, worldsdfs(i), i );
        h = closest( h, n );
    }
    return h;
}

vec3 normal( hit h ) {
    vec3 position = h.hit_position;
    int objid = h.hit_object;
    sdf obj = worldsdfs(h.hit_object);
    return normalize(vec3(
        hit_sdf( ray( position+vec3(0.001,0.0,0.0), vec3(.0,.0,.0), 0.0, -1 ), obj, objid ).distance - 
        hit_sdf( ray( position-vec3(0.001,0.0,0.0), vec3(.0,.0,.0), 0.0, -1 ), obj, objid ).distance,
        hit_sdf( ray( position+vec3(0.0,0.001,0.0), vec3(.0,.0,.0), 0.0, -1 ), obj, objid ).distance - 
        hit_sdf( ray( position-vec3(0.0,0.001,0.0), vec3(.0,.0,.0), 0.0, -1 ), obj, objid ).distance,
        hit_sdf( ray( position+vec3(0.0,0.0,0.001), vec3(.0,.0,.0), 0.0, -1 ), obj, objid ).distance - 
        hit_sdf( ray( position-vec3(0.0,0.0,0.001), vec3(.0,.0,.0), 0.0, -1 ), obj, objid ).distance
    ));
}

ray refraction( ray r, hit h ) {
    vec3 nrml = normal( h );
    vec3 newdir = refract( r.direction, nrml, 1.0/1.3 );
    return ray( h.hit_position, newdir, 0.0, h.hit_object );
}


vec3 colorize( hit h ) {
    sdf hitobj = worldsdfs(h.hit_object);
    vec3 color = hitobj.color;
    if ( hitobj.type == 2 ) {
        bool col = mod(h.hit_position.x,4.0) <= 2.0 ^^ mod(h.hit_position.z,4.0) <= 2.0;
        if( col ) {
         color = vec3(0.8078, 0.8078, 0.8078);
        } else {
         color = vec3(0.1516, 0.1516, 0.1516);
        }
    }
    return color;
}

float sun_trace( hit h ) {
    float occlusion = 1.0;
    ray r = ray( h.hit_position, sun_dir, 0.0, h.hit_object );
    r = rayfwd( r, min_distance * 4.0 );
    for( int i=0; i < max_steps; i++) {
        if( r.length > max_depth ) return occlusion;
        hit c_obj = world( r );
        if( c_obj.distance < min_distance) {
            sdf hit_object = worldsdfs( c_obj.hit_object );
            if( hit_object.type < 100 ) {
            	return 0.0;
            } else {
                r = ray( r.position, r.direction, r.length, c_obj.hit_object );
                vec3 c = colorize( c_obj );
                occlusion = occlusion * ( 0.299*c.x + 0.587*c.y + 0.114*c.z );
                c_obj = world( r );
            }
        } 
        r = rayfwd( r, c_obj.distance );
    }
    return occlusion;
}

vec4 trace( ray r ) {
    r = rayfwd( r, min_distance );
    vec3 refractionTint = vec3(1,1,1);
    for( int i=0; i < max_steps; i++) {
        if( r.length > max_depth ) return vec4(0,0.2,0,1);
        hit c_obj = world( r );
        if( c_obj.distance < min_distance || c_obj.distance < min_distance*10.0 && i > max_steps - 2 ) {
            float brightness;
            float shadow = max( 0.2, sun_trace( c_obj ) );
            vec3 nrml = normal( c_obj );

            float lambertian = max(dot(sun_dir,nrml), 0.0);
            float specular = 0.0;

            if(lambertian > 0.0) {
                vec3 halfDir = normalize(sun_dir - r.direction);
                float specAngle = max(dot(halfDir, nrml), 0.0);
                specular = specAngle * specAngle * specAngle * specAngle;
                specular = specular * specular * specular * specular;
                specular = specular * specular * specular * specular;
            }
            brightness = shadow * min( lambertian*0.8  + specular*0.8, 1.0);
                
            if( worldsdfs(c_obj.hit_object).type >= 100 ) {
                r = refraction( r, c_obj );
               	refractionTint = refractionTint * colorize( c_obj ).xyz * brightness;
                c_obj = world(r);
            } else {
    	        vec3 color = colorize( c_obj ).xyz * brightness * refractionTint;
	            return vec4( color.xyz, 1);
            }
        }
        r = rayfwd( r, c_obj.distance );
    }
    return vec4(0,0,0.2,1);
}

vec3 viewdirection( vec2 screenpos, vec3 camerapos, vec3 lookingat, vec3 up ) 
{
    vec3 forward = normalize( lookingat - camerapos );
    vec3 left = normalize( cross( forward, up ) );
    vec3 orthoup = cross( left, forward );
    return normalize(forward * 0.2 
            + screenpos.x * left * 0.2 
            + screenpos.y * orthoup * 0.2);
}

void main()
{
    vec2 fragPos = (gl_FragCoord.xy / iResolution.xy - 0.5);//fragCoord.xy / vec2(1000.0,1000.0)) -0.5;
    //fragColor = vec4(1.0, fragPos.x, sin(iTime), 1.0);
    vec3 camera = vec3( sin(iTime)*3.0+4.0, sin(iTime)*5.0+5.0, cos(iTime)*1.0 );
    vec3 lookat = vec3(0, 0, 0);
    vec3 viewdir = viewdirection( fragPos, camera,lookat, vec3(0.0,1.0,0.0) );
    ray pixelray = ray( camera, viewdir, 0.0, -1);
    gl_FragColor = trace( pixelray );
}
