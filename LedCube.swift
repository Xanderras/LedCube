//------------------------------------------------------------------------------
//
// LedCube.swift4a
// Swift For Arduino
//
// Created by xander rasschaert on 08/03/2023.
// Copyright © 2023 xander rasschaert. All rights reserved.
//
//------------------------------------------------------------------------------

import AVR

struct CubeFrame {
    var size: UInt32
    var delay: UInt32
    var sequence: UnsafeMutablePointer<UInt8>?
}

class LedCube {
     var levels: UInt8
     var cols: UInt8
     var num: UInt8
     var buffer: [[UInt8]]
     var colPins: [UInt8]
     var levelPins: [UInt8]
     var bufferEnabled: Bool
     var bufferInverted: Bool

    init(size: UInt8, lp: [UInt8], cp: [UInt8]) {
        levels = size
        cols = size * size
        num = size * size * size

        buffer = Array(repeating: Array(repeating: 0, count: Int(self.cols)), count: Int(self.levels))
        
    
        
        //Array(repeating: Array(repeating: 0, count: Int(cols)), count: Int(levels))
        levelPins = lp
        colPins = cp

        for i in 0..<Int(levels) {
            pinMode(pin: levelPins[i]!, mode: OUTPUT)
            buffer[i] = Array(repeating: 0, count: Int(cols))
        }

        for i in 0..<Int(cols) {
            pinMode(pin: colPins[i]!, mode: OUTPUT)
        }

        clearBuffer()
        randomSeed(analogRead(0))
        //SetupSerial()
    }

    func light(lv: UInt8, col: UInt8, val: UInt8) {
        if (lv < levels && col < cols) {
            if (bufferEnabled){
                buffer[Int(lv)][col] = val
            }
            else {
                digitalWrite(pin: colPins[col]!, value: (val == 0 ? LOW : HIGH))
                digitalWrite(pin: levelPins[lv]!, value: (val == 0 ? LOW : HIGH))
            }
        }
    }
    func lightOn(lv: UInt8, col: UInt8) {
        light(lv: lv, col: col, val: (bufferInverted ? 0 : 1))
    }

    func lightOff(lv: UInt8, col: UInt8) {
        light(lv: lv, col: col, val: (bufferInverted ? 0 : 1))
    }

    func lightPulse(lv: UInt8, col: UInt8, wait: UInt16 = 5) {
        lightOn(lv: lv, col: col)
        if (!bufferEnabled) {
            delay(ms: wait)
            lightOff(lv: lv, col: col)
        }
    }
    
    // TODO: ask to paul about the time being an let
    func lightSequence(seq: [UInt8], length: UInt8, time: UInt16 = 5, gap: UInt16 = 1) {
        if(length % 2 == 1) {
            return
        }
        
        var timeVal: UInt16
        
        if(bufferEnabled) {
            timeVal = 1
        }
        else {
            timeVal = time
        }
    
        for d in 0..<timeVal {
            for s in stride(from: 0, to: length, by: 2) {
                if bufferEnabled {
                    lightOn(lv: seq[s]!, col: seq[s+1]!)
                } else {
                    lightPulse(lv: seq[s]!, col: seq[s+1]!, wait: gap)
                }
            }
        }
    }
    
    func lightLevel(_ r: UInt8, delay: UInt16) {
        if r > 0 && r <= levels {
            var seq = [UInt8](repeating: UInt8(0), count: Int(cols * 2))
            for c in 0..<cols {
                let i = c * 2
                seq[i] = r - 1
                seq[i + 1] = UInt8(c)
            }
            lightSequence(seq, size: seq.count, delay: delay)
        }
    }
    
    func lightRow(_ r: UInt8, level: UInt8, wait: UInt16) {
        if r > 0 && level > 0 && r <= cols * 2 && r <= levels {
            let start = r <= levels ? r - 1 : (r - levels - 1) * levels
            let inc = r <= levels ? levels : 1
            
            let seq: [UInt8] = [r - 1, start, r - 1, start + inc, r - 1, start + inc * 2]
            
            lightSequence(seq: seq, length: UInt8(seq.count), gap: wait)
        }
    }
    
    func lightPlane(r: UInt8, wait: UInt16 = 50) {
        if (r != 0 && r <= (cols * 2)) {
            var start: UInt8 = (r <= levels ? r-1 : (r - levels - 1) * levels)
            var inc: UInt8 = (r <= levels ? levels : 1)
            var seq: [UInt8]
            var index = 0
            
            for level in 0..<levels{
                for i in 0..<3 {
                    seq[index] = level
                    seq[index + 1] = start + (inc * i)
                    index += 2
                }
            }
            
            // TODO: what is the 3th param
            lightSequence(seq: seq, length: UInt8(seq.count), gap: wait)
        }
    }
    func lightColumn(col: UInt8, wait: UInt16 = 50) {
        if col != 0 && col <= cols {
            var seq: [UInt8] = [0, col-1, 1, col-1, 2, col-1]
            lightSequence(seq: seq, length: UInt8(seq.count), gap: wait)
        }
    }
    func lightDrop(col: UInt8, wait: UInt16 = 50) {
        for r in (0..<levels).reversed() {
            lightPulse(lv: r-1, col: col-1, wait: wait)
        }
    }
    func lightPerimeter(level: UInt8, rotations: UInt8, wait: UInt16 = 50){
        var seq: [UInt8] = [level, 0, level, 1, level, 2, level, 5, level, 8, level, 7, level, 6, level, 3]
        lightSequence(seq: seq, length: UInt16(seq.length), time: rotations, gap: wait)
    }
    func randomLight(numLights: UInt8, wait: UInt16 = 50){
        for l in 0..<numLights{
            lightPulse(lv: random(in: 0..<levels), col: random(in: 0..<cols), wait: wait)
        }
    }
    func randomColumn(numColumns: UInt8 = 1, wait: UInt16 = 50){
        for c: UInt8 in 0..<numColumns {
            lightColumn(col: UInt8.random(in: 1...cols+1), wait: wait)
        }
    }
    func lightsOut(wait: UInt16 = 5) {
        enableBuffer()
        fillBuffer()
        drawBuffer(25)
        var l: UInt8 = 0
        var c: UInt8 = 0
        var max: UInt8 = num
        for w in 0..<num {
            // lower bound is inclusive, upper is exclusive
            l = UInt8.random(in: 0..<levels)
            c = UInt8.random(in: 0..<cols)
            
            if getBufferAt(lv: l, col: c) == UInt8(1) {
                lightOff(lv: l, col: c)
                drawBuffer(wait)
            }
        }
        enableBuffer(enable: false)
    }

    func createFrame(sequence: UnsafeMutablePointer<UInt8>, size: UInt16, delay: UInt16) -> UnsafeMutablePointer<cubeFrame> {
        // allocate memory which will be reclaimed in lightFrames
        let f = UnsafeMutablePointer<cubeFrame>.allocate(capacity: 1)
        f.pointee.sequence = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))
        f.pointee.sequence.initialize(from: sequence, count: Int(size))
        f.pointee.size = size
        f.pointee.delay = delay
        return f
    }
    
//    func destroyFrame(frame: UnsafeMutablePointer<cubeFrame>) {
//        free(frame.pointee.sequence)
//        free(frame)
//    }
    
    func lightFrames(frames: UnsafeMutablePointer<UnsafeMutablePointer<cubeFrame>?>, length: UInt16) {
        for f in 0..<length {
            lightSequence(frames[f].pointee.sequence, frames[f].pointee.size, frames[f].pointee.delay)
            // reclaim memory allocated in createFrame to prevent a leak
//            destroyFrame(frames[f])
        }
    }

    func enableBuffer(enable: Bool = true){
        bufferEnabled = enable
        if(!bufferEnabled) {
            invertBuffer(invert: false)
        }
    }
    
    func invertBuffer(invert: Bool = true){
        bufferInverted = invert
    }
    
    func clearBuffer(){
        setBuffer(0)
    }
    
    func fillBuffer() {
        setBuffer(1)
    }
    
    func drawBuffer(_ wait: UInt16) {
        var seq = [UInt8](repeating: 0, count: Int(num*2))
        var n: UInt8 = 0
        
        for lv: UInt8 in 0..<levels {
            for col: UInt8 in 0..<cols {
                if buffer[Int(lv)][Int(col)] == 1 {
                    seq[Int(n)] = lv
                    seq[Int(n)+1] = col
                    n += 2
                }
            }
        }
        
        enableBuffer(enable: false)
        lightSequence(seq, UInt16(seq.count), wait)
        enableBuffer()
    }

    func getBufferAt(lv: UInt8, col: UInt8) -> UInt8 {
        return buffer[lv][col]
    }

    // TODO: ask to paul
//    deinit
}
