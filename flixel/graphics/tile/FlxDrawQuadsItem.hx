package flixel.graphics.tile;

import openfl.display.ShaderInput;
import openfl.display3D.Context3DTextureFilter;
#if FLX_DRAW_QUADS
import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import openfl.Vector;
import openfl.display.ShaderParameter;
import openfl.geom.ColorTransform;

using StringTools;

class FlxDrawQuadsItem extends FlxDrawBaseItem<FlxDrawQuadsItem>
{
	static inline var VERTICES_PER_QUAD = #if (openfl >= "8.5.0") 4 #else 6 #end;

	public var shader:FlxShader;
	public var instance:FlxShader;

	var rects:Vector<Float>;
	var transforms:Vector<Float>;
	var alphas:Array<Float>;
	var colorMultipliers:Array<Float>;
	var colorOffsets:Array<Float>;

	public function new()
	{
		super();
		type = FlxDrawItemType.TILES;
		rects = new Vector<Float>();
		transforms = new Vector<Float>();
		alphas = [];
	}

	override public function reset():Void
	{
		super.reset();
		rects.length = 0;
		transforms.length = 0;
		alphas.splice(0, alphas.length);
		if (colorMultipliers != null)
			colorMultipliers.splice(0, colorMultipliers.length);
		if (colorOffsets != null)
			colorOffsets.splice(0, colorOffsets.length);
	}

	override public function dispose():Void
	{
		super.dispose();
		rects = null;
		transforms = null;
		alphas = null;
		colorMultipliers = null;
		colorOffsets = null;
	}

	override public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform):Void
	{
		var rect = frame.frame;
		rects.push(rect.x);
		rects.push(rect.y);
		rects.push(rect.width);
		rects.push(rect.height);

		transforms.push(matrix.a);
		transforms.push(matrix.b);
		transforms.push(matrix.c);
		transforms.push(matrix.d);
		transforms.push(matrix.tx);
		transforms.push(matrix.ty);

		for (i in 0...VERTICES_PER_QUAD)
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);

		if (colored || hasColorOffsets)
		{
			if (colorMultipliers == null)
				colorMultipliers = [];

			if (colorOffsets == null)
				colorOffsets = [];

			for (i in 0...VERTICES_PER_QUAD)
			{
				if (transform != null)
				{
					colorMultipliers.push(transform.redMultiplier);
					colorMultipliers.push(transform.greenMultiplier);
					colorMultipliers.push(transform.blueMultiplier);

					colorOffsets.push(transform.redOffset);
					colorOffsets.push(transform.greenOffset);
					colorOffsets.push(transform.blueOffset);
					colorOffsets.push(transform.alphaOffset);
				}
				else
				{
					colorMultipliers.push(1);
					colorMultipliers.push(1);
					colorMultipliers.push(1);

					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
				}

				colorMultipliers.push(1);
			}
		}
	}

	private static var ERROR_BITMAP = new openfl.display.BitmapData(1, 1, true, 0xFFff0000);

	#if !flash
	override public function render(camera:FlxCamera):Void
	{
		if (rects.length == 0)
			return;

		var shader = shader != null ? shader : graphics.shader;
		if (shader == null || graphics == null || shader.bitmap == null || graphics.bitmap == null)
		{
			if (FlxG.showDestroyedGraphics)
			{
				#if (openfl > "8.7.0")
				camera.canvas.graphics.overrideBlendMode(blend);
				#end
				camera.canvas.graphics.beginBitmapFill(ERROR_BITMAP);
				camera.canvas.graphics.drawQuads(rects, null, transforms);
				camera.canvas.graphics.endFill();
			}
			return;
		}

		var renderShader = shader;

		/*if ((shader is FlxShader))
			{
				var shader:FlxShader = cast shader;
		 */
		@:privateAccess
		if (instance != null)
		{
			renderShader = instance;

			/*for (field in Reflect.fields(shader.__inputBitmapData))
				{
					var renderShaderInput = Reflect.field(renderShader, field);
					var originalShaderInput = Reflect.field(shader, field);
					for (f in ["input", "channels", "filter", "height", "mipFilter", "width", "wrap"])
						Reflect.setField(renderShaderInput, f, Reflect.field(originalShaderInput, f));
				}

				for (property in ["__paramBool", "__paramFloat", "__paramInt"])
				{
					for (field in Reflect.fields(Reflect.field(shader, property)))
					{
						var renderShaderProp = Reflect.field(renderShader, field);
						var originalShaderProp = Reflect.field(shader, field);
						Reflect.setField(renderShaderProp, "value", Reflect.field(originalShaderProp, "value"));
					}
			}*/

			for (field in Reflect.fields(shader.data))
			{
				// if (field == "openfl_ColorOffset" || field == "openfl_TextureSize" || field == "colorMultiplier" || field == "openfl_HasColorTransform"
				//	|| field == "hasTransform" || field == "bitmap" || field == "hasColorTransform" || field == "openfl_Alpha" || field == "colorOffset"
				//	|| field == "alpha" || field == "openfl_ColorMultiplier" || field == "openfl_TextureCoord" || field == "openfl_Position"
				//	|| field == "openfl_Matrix")
				//	continue;
				// if (field == "bitmap")
				//	continue;
				var renderShaderInput:Dynamic = Reflect.field(renderShader.data, field);
				var originalShaderInput:Dynamic = Reflect.field(shader.data, field);
				// trace("");
				// trace(renderShaderInput, (renderShaderInput is ShaderInput), Std.isOfType(renderShaderInput, ShaderInput));
				// trace((renderShaderInput is ShaderInput));
				// trace(Std.isOfType(renderShaderInput, ShaderInput));
				// trace(Reflect.hasField(originalShaderInput, "input"));
				// trace(Reflect.fields(originalShaderInput).contains("input"));
				// trace(Reflect.getProperty(originalShaderInput, "input") != null);
				// trace(Reflect.fields(originalShaderInput));
				// trace((renderShaderInput is ShaderParameter));
				var cl = Std.string(Type.getClass(originalShaderInput));

				// if (field != "_camSize")
				//	trace("Copying " + field + " " + cl + " " + renderShaderInput);

				if (cl.startsWith("openfl.display.ShaderParameter"))
				{
					// if (field != "_camSize")
					//	trace("Copying " + field + " " + originalShaderInput.value + renderShaderInput.value);
					renderShaderInput.value = originalShaderInput.value;
				}
				else if (cl.startsWith("openfl.display.ShaderInput"))
				{
					// TODO: ShaderInput
				}
			}
			// trace(Reflect.fields(shader.data) + " " + Reflect.fields(renderShader.data));
		}
		// }

		renderShader.bitmap.input = graphics.bitmap;

		var aaType:Context3DTextureFilter = LINEAR;
		if (FlxG.forceNoAntialiasing)
			aaType = NEAREST;

		renderShader.bitmap.filter = (camera.antialiasing || antialiasing) ? aaType : NEAREST;
		renderShader.alpha.value = alphas;

		if (colored || hasColorOffsets)
		{
			renderShader.colorMultiplier.value = colorMultipliers;
			renderShader.colorOffset.value = colorOffsets;
		}

		setParameterValue(renderShader.hasTransform, true);
		setParameterValue(renderShader.hasColorTransform, colored || hasColorOffsets);

		#if (openfl > "8.7.0")
		camera.canvas.graphics.overrideBlendMode(blend);
		#end
		camera.canvas.graphics.beginShaderFill(renderShader);
		camera.canvas.graphics.drawQuads(rects, null, transforms);
		super.render(camera);
	}

	inline function setParameterValue(parameter:ShaderParameter<Bool>, value:Bool):Void
	{
		if (parameter.value == null)
			parameter.value = [];
		parameter.value[0] = value;
	}
	#end
}
#end
