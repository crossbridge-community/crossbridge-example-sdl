/*
 * =BEGIN MIT LICENSE
 * 
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 The CrossBridge Team
 * https://github.com/crossbridge-community
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 * =END MIT LICENSE
 *
 */
package com.adobe.flascc {
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.DisplayObjectContainer;
import flash.display.Sprite;
import flash.display.Stage3D;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.display3D.Context3D;
import flash.display3D.Context3DRenderMode;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.SampleDataEvent;
import flash.geom.Rectangle;
import flash.media.Sound;
import flash.media.SoundChannel;
import flash.text.TextField;
import flash.utils.ByteArray;

import com.adobe.flascc.*;
import com.adobe.flascc.vfs.*;
import GLS3D.GLAPI;

public class Console extends Sprite implements ISpecialFile {
    // CORE
    private var _frameCounter:TextField;
    private var _textField:TextField;
    private var _mainloopTickPtr:int;
    private var _inputContainer;
    // STAGE3D
    private var _stage3D:Stage3D;
    private var _context3D:Context3D;
    // BLITTING
    private var _bitmapData:BitmapData;
    private var _bitmap:Bitmap;
    private var _bitmapRectangle:Rectangle;
    // VFS
    private var _fs:InMemoryBackingStore;
    // FLAGS
    private var _isRendered:Boolean;
    private var _isInitialized:Boolean;

    private var _useStage3D:Boolean = true;
    private var _useBlitting:Boolean = !_useStage3D;
    // INPUT
    private var _keyBA:ByteArray = new ByteArray()
    private var _keyX:int = 0;
    private var _keyY:int = 0;
    // SOUND
    private var _soundBuffer:ByteArray;
    private var _soundPos:int = 0;
    private var _sound:Sound = null;
    private var _soundChannel:SoundChannel;
    // DISPLAY
    private var _frameCount:int;
    private var _vglttyargs:Vector.<int> = new Vector.<int>();
    private var _vbuffer:int;
    private var _vgl_mx:int;
    private var _vgl_my:int;
    private var _kp:int;
    // ISpecialFile
    public var exitHook:Function;
    // CONSTS
    private const EMPTY_VECTOR:Vector.<int> = new Vector.<int>();

    // CONSTRUCTOR

    public function Console(container:DisplayObjectContainer = null) {
        CModule.rootSprite = container ? container.root : this;
        if (CModule.runningAsWorker()) {
            return;
        }
        if (container) {
            container.addChild(this);
            onAdded(null);
        } else {
            addEventListener(Event.ADDED_TO_STAGE, onAdded);
        }
    }

    // EVENT HANDLERS

    private function onAdded(e:Event):void {
        log("onAdded");
        // STAGE
        stage.frameRate = 60;
        stage.align = StageAlign.TOP_LEFT;
        stage.scaleMode = StageScaleMode.NO_SCALE;
        // STAGE3d
        _stage3D = stage.stage3Ds[0];
        _stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
        _stage3D.requestContext3D(Context3DRenderMode.AUTO);
    }

    private function createChildren():void {
        log("createChildren");
        // ROOT
        _inputContainer = new Sprite()
        addChild(_inputContainer);
        // BLITTING
        if(_useBlitting) {
            _bitmapData = new BitmapData(800, 600, false);
            _bitmap = new Bitmap(_bitmapData);
            _bitmapRectangle = new Rectangle(0, 0, _bitmapData.width, _bitmapData.height);
            _bitmapData.fillRect(_bitmapData.rect, 0);
            _inputContainer.addChild(_bitmap);
        }
        // LOGGING
        _textField = new TextField;
        _textField.multiline = true;
        _textField.selectable = false;
        _textField.width = 800;
        _textField.height = 600;
        _textField.textColor = 0x666666;
        _inputContainer.addChild(_textField);
        _textField.border = true;
        // FRAME COUNTER
        _frameCounter = new TextField;
        _frameCounter.width = 40;
        _frameCounter.height = 20;
        _frameCounter.textColor = 0x666666;
        _frameCounter.x = 760;
        _inputContainer.addChild(_frameCounter);
    }

    private function onContextCreated(event:Event):void {
        log("onContextCreated");

        createChildren();

        if(_useStage3D) {
            _context3D = _stage3D.context3D
            _context3D.configureBackBuffer(stage.stageWidth, stage.stageHeight, 2, true /*enableDepthAndStencil*/)
            _context3D.enableErrorChecking = true;
            log("Stage3D context: " + _context3D.driverInfo);
            if (_context3D.driverInfo.indexOf("Software") != -1) {
                log("Software mode unsupported...");
                return;
            }
            GLAPI.init(_context3D, null, stage);
            var gl:GLAPI = GLAPI.instance;
            gl.context.clear(0.0, 0.0, 0.0);
            gl.context.present();
        }

        // file system
        CModule.vfs.console = this;
        _fs = new myfs();
        CModule.vfs.addBackingStore(_fs, null);

        // starting c code
        CModule.startAsync(this, new <String>["/main.swf"]);

        // VIDEO
        _vbuffer = CModule.getPublicSymbol("__avm2_vgl_argb_buffer");
        _vgl_mx = CModule.getPublicSymbol("vgl_cur_mx");
        _vgl_my = CModule.getPublicSymbol("vgl_cur_my");

        // INPUT
        stage.addEventListener(KeyboardEvent.KEY_DOWN, onBufferKeyDown);
        stage.addEventListener(KeyboardEvent.KEY_UP, onBufferKeyUp);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onBufferMouseMove);
        stage.addEventListener (Event.ENTER_FRAME, onFrameEnter);
        stage.addEventListener(Event.RESIZE, onStageResized);
        //onFrameEnter(null);
    }

    private function initialize():void {
        log("initialize");
        _isInitialized = true;
        _mainloopTickPtr = CModule.getPublicSymbol("_Z4drawv");

        _sound = new Sound();
        _sound.addEventListener( SampleDataEvent.SAMPLE_DATA, onSoundData);
        _soundPos = 0;
        _soundChannel = _sound.play()
        _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundComplete);


    }

    private function onFrameEnter(event:Event):void {
        if (!_isInitialized) {
            initialize();
        }
        CModule.serviceUIRequests();
        CModule.write32(_vgl_mx, _keyX);
        CModule.write32(_vgl_my, _keyY);
        if(_useStage3D) {
            CModule.callI(_mainloopTickPtr, EMPTY_VECTOR);
            GLAPI.instance.context.clear(1.0, 0.0, 0.0);
            GLAPI.instance.context.present();
        }
        if(_useBlitting) {
            var ram:ByteArray = CModule.ram;
            ram.position = CModule.read32(_vbuffer)
            if (ram.position != 0) {
                _frameCount++;
                _frameCounter.text = String(_frameCount);
                _bitmapData.setPixels(_bitmapRectangle, ram)
            }
        }
    }

    private function onStageResized(event:Event):void {
        log("onStageResized");
        // need to reconfigure back buffer
        _context3D.configureBackBuffer(stage.stageWidth, stage.stageHeight, 2, true /*enableDepthAndStencil*/)
    }

    private function onError(event:Event):void {
        log(event.toString());
    }

    // Keyboard

    public function onBufferMouseMove(event:MouseEvent) {
        event.stopPropagation();
        _keyX = event.stageX;
        _keyY = event.stageY;
    }

    public function onBufferKeyDown(event:KeyboardEvent) {
        _keyBA.writeByte(int(event.keyCode & 0x7F));
    }

    public function onBufferKeyUp(event:KeyboardEvent) {
        _keyBA.writeByte(int(event.keyCode | 0x80));
    }

    // Sound

    public function onSoundComplete(e:Event):void {
        _soundChannel.removeEventListener(Event.SOUND_COMPLETE, onSoundComplete)
        _soundChannel = _sound.play()
        _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundComplete)
    }

    public function onSoundData(event:SampleDataEvent):void {
        event.data.length = 0
        _soundBuffer = event.data

         if(_frameCount == 0)
            return;

        /* if(engineticksoundptr == 0)
         engineticksoundptr = CModule.getPublicSymbol("engineTickSound")

         if(engineticksoundptr)
         CModule.callI(engineticksoundptr, emptyArgs)*/
    }

    // ISpecialFile

    public function exit(code:int):Boolean {
        // default to unhandled
        return exitHook ? exitHook(code) : false;
    }

    public function write(fd:int, bufPtr:int, nbyte:int, errnoPtr:int):int {
        var str:String = CModule.readString(bufPtr, nbyte)
        log(str)
        return nbyte
    }

    /**
     * libVGL expects to be able to read Keyboard input from
     * file descriptor zero using normal C IO.
     */
    public function read(fd:int, bufPtr:int, nbyte:int, errnoPtr:int):int {
        if (fd == 0 && nbyte == 1) {
            _keyBA.position = _kp++
            if (_keyBA.bytesAvailable) {
                CModule.write8(bufPtr, _keyBA.readUnsignedByte())
                return 1
            } else {
                _keyBA.length = 0
                _keyBA.position = 0
                _kp = 0
            }
        }
        return 0
    }

    public function fcntl(fd:int, com:int, data:int, errnoPtr:int):int {
        return 0
    }

    public function ioctl(fd:int, com:int, data:int, errnoPtr:int):int {
        _vglttyargs[0] = fd
        _vglttyargs[1] = com
        _vglttyargs[2] = data
        _vglttyargs[3] = errnoPtr
        return CModule.callI(CModule.getPublicSymbol("vglttyioctl"), _vglttyargs);
    }

    // HELPERS

    private function log(message:String):void {
        trace(message);
        if (_textField) {
            _textField.appendText(message + "\n");
            _textField.scrollV = _textField.maxScrollV;
        }
    }

}
}
