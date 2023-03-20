package flixel.graphics.tile;

#if FLX_DRAW_QUADS
import openfl.display.GraphicsShader;
import openfl.display3D._internal.GLProgram;
import openfl.display3D._internal.GLShader;
import openfl.display._internal.ShaderBuffer;
import openfl.utils._internal.Float32Array;
import openfl.utils._internal.Log;
import openfl.display3D.Context3D;
import openfl.display3D.Program3D;
import openfl.utils.ByteArray;

@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.Program3D)
@:access(openfl.display.ShaderInput)
@:access(openfl.display.ShaderParameter)
@:allow(flixel.graphics.tile.FlxDrawQuadsItem)
@:allow(flixel.FlxCamera)
class FlxGraphicsShader extends GraphicsShader
{
	private static var _instances:Map<String, FlxGraphicsShader> = [];

	private var _instance:FlxGraphicsShader;
	private var _isInstance:Bool = false;

	@:glVertexSource("
#pragma header

attribute float alpha;
attribute vec4 colorMultiplier;
attribute vec4 colorOffset;
uniform bool hasColorTransform;

void main(void)
{
	#pragma body

	openfl_Alphav = openfl_Alpha * alpha;

	if (hasColorTransform)
	{
		openfl_ColorOffsetv = colorOffset / 255.0;
		openfl_ColorMultiplierv = colorMultiplier;
	}
}")
	@:glFragmentHeader("
uniform bool hasTransform;
uniform bool hasColorTransform;

vec4 flixel_texture2D(sampler2D bitmap, vec2 coord)
{
	vec4 color = texture2D(bitmap, coord);
	if (!hasTransform)
	{
		return color;
	}

	if (color.a == 0.0)
	{
		return vec4(0.0, 0.0, 0.0, 0.0);
	}

	if (!hasColorTransform)
	{
		return color * openfl_Alphav;
	}

	color = vec4(color.rgb / color.a, color.a);

	mat4 colorMultiplier = mat4(0);
	colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
	colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
	colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
	colorMultiplier[3][3] = openfl_ColorMultiplierv.w;

	color = clamp(openfl_ColorOffsetv + (color * colorMultiplier), 0.0, 1.0);

	if (color.a > 0.0)
	{
		return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
	}
	return vec4(0.0, 0.0, 0.0, 0.0);
}

uniform vec4 _camSize;

float map(float value, float min1, float max1, float min2, float max2) {
	return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

vec2 getCamPos(vec2 pos) {
	vec4 size = _camSize / vec4(openfl_TextureSize, openfl_TextureSize);
	return vec2(map(pos.x, size.x, size.x + size.z, 0.0, 1.0), map(pos.y, size.y, size.y + size.w, 0.0, 1.0));
}
vec2 camToOg(vec2 pos) {
	vec4 size = _camSize / vec4(openfl_TextureSize, openfl_TextureSize);
	return vec2(map(pos.x, 0.0, 1.0, size.x, size.x + size.z), map(pos.y, 0.0, 1.0, size.y, size.y + size.w));
}
vec4 textureCam(sampler2D bitmap, vec2 pos) {
	return flixel_texture2D(bitmap, camToOg(pos));
}
")
	@:glFragmentSource("
#pragma header

void main(void)
{
	gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);
}")
	public function new()
	{
		super();
	}

	public function setCamSize(x:Float, y:Float, width:Float, height:Float)
	{
		data._camSize.value = [x, y, width, height];
	}

	function initInstance(vertexSource:String, fragmentSource:String)
	{
		if (!_isInstance)
		{
			if (_instances.exists(vertexSource + fragmentSource))
			{
				_instance = _instances.get(vertexSource + fragmentSource);
				_instance.__context = __context;
				trace("reusing instance");
			}
			else
			{
				_instance = Type.createInstance(Type.getClass(this), []); // new FlxGraphicsShader();
				_instance._isInstance = true;
				_instance.__context = __context;
				_instance.glVertexSource = vertexSource;
				_instance.glFragmentSource = fragmentSource;
				_instance.__init();

				_instances.set(vertexSource + fragmentSource, _instance);
				trace("Making instance");
			}
		}
	}

	@:noCompletion override private function __initGL():Void
	{
		if (__glSourceDirty || __paramBool == null)
		{
			__glSourceDirty = false;
			program = null;

			__inputBitmapData = new Array();
			__paramBool = new Array();
			__paramFloat = new Array();
			__paramInt = new Array();

			__processGLData(glVertexSource, "attribute");
			__processGLData(glVertexSource, "uniform");
			__processGLData(glFragmentSource, "uniform");
		}

		if (__context != null && program == null)
		{
			var gl = __context.gl;

			var prefix = "";

			if (!_isInstance)
			{
				#if (js && html5)
				prefix = (precisionHint == FULL ? "precision mediump float;\n" : "precision lowp float;\n");
				#else
				prefix = "#ifdef GL_ES\n"
					+ (precisionHint == FULL ? "#ifdef GL_FRAGMENT_PRECISION_HIGH\n"
						+ "precision highp float;\n"
						+ "#else\n"
						+ "precision mediump float;\n"
						+ "#endif\n" : "precision lowp float;\n")
					+ "#endif\n\n";
				#end
			}

			var vertex = glVertexSource;
			var fragment = glFragmentSource;

			var id = vertex + fragment;

			if (__context.__programs.exists(id))
			{
				program = __context.__programs.get(id);
			}
			else
			{
				program = __context.createProgram(GLSL);

				// TODO
				// program.uploadSources (vertex, fragment);
				program.__glProgram = __createGLProgram(vertex, fragment);

				__context.__programs.set(id, program);
			}

			if (program != null)
			{
				glProgram = program.__glProgram;

				for (input in __inputBitmapData)
				{
					if (input.__isUniform)
					{
						input.index = gl.getUniformLocation(glProgram, input.name);
					}
					else
					{
						input.index = gl.getAttribLocation(glProgram, input.name);
					}
				}

				for (parameter in __paramBool)
				{
					if (parameter.__isUniform)
					{
						parameter.index = gl.getUniformLocation(glProgram, parameter.name);
					}
					else
					{
						parameter.index = gl.getAttribLocation(glProgram, parameter.name);
					}
				}

				for (parameter in __paramFloat)
				{
					if (parameter.__isUniform)
					{
						parameter.index = gl.getUniformLocation(glProgram, parameter.name);
					}
					else
					{
						parameter.index = gl.getAttribLocation(glProgram, parameter.name);
					}
				}

				for (parameter in __paramInt)
				{
					if (parameter.__isUniform)
					{
						parameter.index = gl.getUniformLocation(glProgram, parameter.name);
					}
					else
					{
						parameter.index = gl.getAttribLocation(glProgram, parameter.name);
					}
				}
			}

			initInstance(vertex, fragment);
		}
	}
}
#end
