extern crate wasm_bindgen;
extern crate js_sys;
extern crate web_sys;
extern crate console_error_panic_hook;
use std::panic;
use js_sys::WebAssembly;
use web_sys::console;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use web_sys::{WebGlProgram, WebGl2RenderingContext, WebGlShader, HtmlCanvasElement};
use std::cell::RefCell;
use std::rc::Rc;

#[wasm_bindgen]
extern {
    fn alert(s: &str);
}

pub struct Motti {
    program: WebGlProgram,
    context: WebGl2RenderingContext,
    canvas: HtmlCanvasElement,
    count: i32,
    lastCountTime: f64,
    stopped: bool
}

impl Motti {
    pub fn new() -> Result<Rc<RefCell<Motti>>,JsValue> {
        let document = web_sys::window().unwrap().document().unwrap();
        let canvas = document.get_element_by_id("canvas").unwrap();
        let canvas: web_sys::HtmlCanvasElement = canvas.dyn_into::<web_sys::HtmlCanvasElement>()?;

        let context = canvas
            .get_context("webgl2")?
            .unwrap()
            .dyn_into::<WebGl2RenderingContext>()?;

        let vert_shader = compile_shader(
            &context,
            WebGl2RenderingContext::VERTEX_SHADER,
            r#"#version 300 es
            in vec4 position;
            void main() {
                gl_Position = position;
            }
        "#,
        )?;
        let frag_shader = compile_shader(
            &context,
            WebGl2RenderingContext::FRAGMENT_SHADER,
            include_str!("color.frag"),
        )?;
        let program = link_program(&context, [vert_shader, frag_shader].iter())?;
        context.use_program(Some(&program));

        let vertices: [f32; 18] = [-1.0, -1.0, 0.0, -1.0, 1.0, 0.0, 1.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, 1.0,-1.0, 0.0 ];
        let memory_buffer = wasm_bindgen::memory()
            .dyn_into::<WebAssembly::Memory>()?
            .buffer();
        let vertices_location = vertices.as_ptr() as u32 / 4;
        let vert_array = js_sys::Float32Array::new(&memory_buffer)
            .subarray(vertices_location, vertices_location + vertices.len() as u32);

        let buffer = context.create_buffer().ok_or("failed to create buffer")?;
        context.bind_buffer(WebGl2RenderingContext::ARRAY_BUFFER, Some(&buffer));
        context.buffer_data_with_array_buffer_view(
            WebGl2RenderingContext::ARRAY_BUFFER,
            &vert_array,
            WebGl2RenderingContext::STATIC_DRAW,
        );
        context.vertex_attrib_pointer_with_i32(0, 3, WebGl2RenderingContext::FLOAT, false, 0, 0);
        context.enable_vertex_attrib_array(0);

        context.clear_color(0.0, 0.0, 0.0, 1.0);
        context.clear(WebGl2RenderingContext::COLOR_BUFFER_BIT);
        let motti1 = Rc::new( RefCell::new( Motti{ program, context, canvas, count: 0, lastCountTime: 0.0, stopped: false } ) ); 
        let motti2 = motti1.clone();

        let f = Rc::new(RefCell::new(None));
        let g = f.clone();
        *g.borrow_mut() = Some(Closure::wrap(Box::new(move || {
            motti1.borrow_mut().gameloop().unwrap();
            if !motti1.borrow_mut().stopped {
                request_animation_frame(f.borrow().as_ref().unwrap());
            };
        }) as Box<FnMut()>));
        request_animation_frame(g.borrow().as_ref().unwrap());
        Ok(motti2)
    }

    pub fn render( &mut self ) -> Result<(),JsValue> {
        let u_resolution = self.context.get_uniform_location( &self.program, "iResolution");
        self.context.uniform3f( u_resolution.as_ref(), self.canvas.width() as f32, self.canvas.height() as f32, 0.0 );

        let u_time = self.context.get_uniform_location( &self.program, "iTime");
        self.context.uniform1f( u_time.as_ref(), (window().performance().unwrap().now() / 1000.0) as f32 );

        if self.count % 100 == 0 {
            if( self.lastCountTime > 0.0 ) {
                let timeNow = window().performance().unwrap().now();
                let delta = timeNow - self.lastCountTime;
                self.lastCountTime = timeNow;
                console::log_1(&format!("FPS: {}", 100.0/(delta/1000.0) ).into());
            } else {
                self.lastCountTime = window().performance().unwrap().now();
            }
            console::log_1(&format!("Height {} Width {} Count {}", self.canvas.width(), self.canvas.height(), self.count).into());
        };
        self.count+=1;


        self.context.draw_arrays(
            WebGl2RenderingContext::TRIANGLES,
            0,
            6,
        );
        Ok(())        
    }

    pub fn stop( &mut self ) -> () {
        self.stopped = true;
    }

    pub fn gameloop( &mut self ) -> Result<(),JsValue> {
        self.render()?;
        Ok(())
    }
}


fn window() -> web_sys::Window {
    web_sys::window().expect("no global `window` exists")
}

fn request_animation_frame(f: &Closure<FnMut()>) {
    window()
        .request_animation_frame(f.as_ref().unchecked_ref())
        .expect("should register `requestAnimationFrame` OK");
}

static mut motti : Option<Rc<RefCell<Motti>>> = None;

#[wasm_bindgen]
pub fn stop_motti() -> Result<(),JsValue> {
    console::log_1(&"Stopping...".into());
    unsafe {
        match &motti {
            Some( m ) => m.borrow_mut().stop(),
            None => panic!(),
        };
    }
    Ok(())
}

#[wasm_bindgen(start)]
pub fn start() -> Result<(),JsValue>{
    console_error_panic_hook::set_once();
    unsafe {
        motti = Some( Motti::new()? );
    }
    Ok(())
}

fn compile_shader(
    context: &WebGl2RenderingContext,
    shader_type: u32,
    source: &str,
) -> Result<WebGlShader, String> {
    let shader = context
        .create_shader(shader_type)
        .ok_or_else(|| String::from("Unable to create shader object"))?;
    context.shader_source(&shader, source);
    context.compile_shader(&shader);

    if context
        .get_shader_parameter(&shader, WebGl2RenderingContext::COMPILE_STATUS)
        .as_bool()
        .unwrap_or(false)
    {
        Ok(shader)
    } else {
        Err(context
            .get_shader_info_log(&shader)
            .unwrap_or_else(|| "Unknown error creating shader".into()))
    }
}

fn link_program<'a, T: IntoIterator<Item = &'a WebGlShader>>(
    context: &WebGl2RenderingContext,
    shaders: T,
) -> Result<WebGlProgram, String> {
    let program = context
        .create_program()
        .ok_or_else(|| String::from("Unable to create shader object"))?;
    for shader in shaders {
        context.attach_shader(&program, shader)
    }
    context.link_program(&program);

    if context
        .get_program_parameter(&program, WebGl2RenderingContext::LINK_STATUS)
        .as_bool()
        .unwrap_or(false)
    {
        Ok(program)
    } else {
        Err(context
            .get_program_info_log(&program)
            .unwrap_or_else(|| "Unknown error creating program object".into()))
    }
}
