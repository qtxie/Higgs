/*****************************************************************************
*
*                      Higgs JavaScript Virtual Machine
*
*  This file is part of the Higgs project. The project is distributed at:
*  https://github.com/maximecb/Higgs
*
*  Copyright (c) 2012, Maxime Chevalier-Boisvert. All rights reserved.
*
*  This software is licensed under the following license (Modified BSD
*  License):
*
*  Redistribution and use in source and binary forms, with or without
*  modification, are permitted provided that the following conditions are
*  met:
*   1. Redistributions of source code must retain the above copyright
*      notice, this list of conditions and the following disclaimer.
*   2. Redistributions in binary form must reproduce the above copyright
*      notice, this list of conditions and the following disclaimer in the
*      documentation and/or other materials provided with the distribution.
*   3. The name of the author may not be used to endorse or promote
*      products derived from this software without specific prior written
*      permission.
*
*  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
*  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
*  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
*  NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
*  NOT LIMITED TO PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
*  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
*  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*****************************************************************************/

module interp.ops;

import std.stdio;
import std.algorithm;
import std.conv;
import std.math;
import ir.ir;
import ir.ast;
import interp.interp;
import interp.layout;
import interp.string;

void op_set_int(Interp interp, IRInstr instr)
{
    interp.setSlot(
        instr.outSlot,
        Word.intv(instr.args[0].intVal),
        Type.INT
    );
}

void op_set_float(Interp interp, IRInstr instr)
{
    interp.setSlot(
        instr.outSlot,
        Word.floatv(instr.args[0].floatVal),
        Type.FLOAT
    );
}

void op_set_str(Interp interp, IRInstr instr)
{
    auto objPtr = instr.args[1].ptrVal;

    // If the string is null, allocate it
    if (objPtr is null)
    {
        objPtr = getString(interp, instr.args[0].stringVal);
    }

    interp.setSlot(
        instr.outSlot,
        Word.ptrv(objPtr),
        Type.REFPTR
    );
}

void op_set_true(Interp interp, IRInstr instr)
{
    interp.setSlot(
        instr.outSlot,
        TRUE,
        Type.CONST
    );
}

void op_set_false(Interp interp, IRInstr instr)
{
    interp.setSlot(
        instr.outSlot,
        FALSE,
        Type.CONST
    );
}

void op_set_null(Interp interp, IRInstr instr)
{
    interp.setSlot(
        instr.outSlot,
        NULL,
        Type.CONST
    );
}

void op_set_undef(Interp interp, IRInstr instr)
{
    interp.setSlot(
        instr.outSlot,
        UNDEF,
        Type.CONST
    );
}

void op_move(Interp interp, IRInstr instr)
{
    interp.move(
        instr.args[0].localIdx,
        instr.outSlot
    );
}

void TypeCheckOp(Type type)(Interp interp, IRInstr instr)
{
    auto typeTag = interp.getType(instr.args[0].localIdx);

    interp.setSlot(
        instr.outSlot,
        (typeTag == type)? TRUE:FALSE,
        Type.CONST
    );
}

alias TypeCheckOp!(Type.INT) op_is_int;
alias TypeCheckOp!(Type.FLOAT) op_is_float;
alias TypeCheckOp!(Type.REFPTR) op_is_refptr;
alias TypeCheckOp!(Type.RAWPTR) op_is_rawptr;
alias TypeCheckOp!(Type.CONST) op_is_const;

void op_i32_to_f64(Interp interp, IRInstr instr)
{
    auto w0 = interp.getWord(instr.args[0].localIdx);

    interp.setSlot(
        instr.outSlot,
        Word.floatv(cast(int32)w0.intVal),
        Type.FLOAT
    );
}

void op_f64_to_i32(Interp interp, IRInstr instr)
{
    auto w0 = interp.getWord(instr.args[0].localIdx);

    interp.setSlot(
        instr.outSlot,
        Word.intv(cast(int32)w0.floatVal),
        Type.FLOAT
    );
}

void ArithOp(DataType, Type typeTag, uint arity, string op)(Interp interp, IRInstr instr)
{
    static assert (
        typeTag == Type.INT || typeTag == Type.FLOAT
    );

    static assert (
        arity <= 2
    );

    static if (arity > 0)
    {
        auto wX = interp.getWord(instr.args[0].localIdx);
        auto tX = interp.getType(instr.args[0].localIdx);

        assert (
            tX == typeTag,
            "invalid operand 1 type in op \"" ~ op ~ "\" (" ~ DataType.stringof ~ ")"
        );
    }
    static if (arity > 1)
    {
        auto wY = interp.getWord(instr.args[1].localIdx);
        auto tY = interp.getType(instr.args[1].localIdx);

        assert (
            tY == typeTag,
            "invalid operand 2 type in op \"" ~ op ~ "\" (" ~ DataType.stringof ~ ")"
        );
    }

    Word output;

    static if (typeTag == Type.INT)
    {
        static if (arity > 0)
            auto x = cast(DataType)wX.intVal;
        static if (arity > 1)
            auto y = cast(DataType)wY.intVal;
    }
    static if (typeTag == Type.FLOAT)
    {
        static if (arity > 0)
            auto x = cast(DataType)wX.floatVal;
        static if (arity > 1)
            auto y = cast(DataType)wY.floatVal;
    }

    mixin(op);

    static if (typeTag == Type.INT)
        output.intVal = r;
    static if (typeTag == Type.FLOAT)
        output.floatVal = r;

    interp.setSlot(
        instr.outSlot,
        output,
        typeTag
    );
}

alias ArithOp!(int32, Type.INT, 2, "auto r = x + y;") op_add_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x - y;") op_sub_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x * y;") op_mul_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x / y;") op_div_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x % y;") op_mod_i32;

alias ArithOp!(int32, Type.INT, 2, "auto r = x & y;") op_and_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x | y;") op_or_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x ^ y;") op_xor_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x << y;") op_lsft_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = x >> y;") op_rsft_i32;
alias ArithOp!(int32, Type.INT, 2, "auto r = cast(uint32)x >>> y;") op_ursft_i32;
alias ArithOp!(int32, Type.INT, 1, "auto r = ~x;") op_not_i32;

alias ArithOp!(float64, Type.FLOAT, 2, "auto r = x + y;") op_add_f64;
alias ArithOp!(float64, Type.FLOAT, 2, "auto r = x - y;") op_sub_f64;
alias ArithOp!(float64, Type.FLOAT, 2, "auto r = x * y;") op_mul_f64;
alias ArithOp!(float64, Type.FLOAT, 2, "auto r = x / y;") op_div_f64;

alias ArithOp!(float64, Type.FLOAT, 1, "auto r = sin(x);") op_sin_f64;
alias ArithOp!(float64, Type.FLOAT, 1, "auto r = cos(x);") op_cos_f64;
alias ArithOp!(float64, Type.FLOAT, 1, "auto r = sqrt(x);") op_sqrt_f64;

void ArithOpOvf(DataType, Type typeTag, string op)(Interp interp, IRInstr instr)
{
    auto wX = interp.getWord(instr.args[0].localIdx);
    auto tX = interp.getType(instr.args[0].localIdx);
    auto wY = interp.getWord(instr.args[1].localIdx);
    auto tY = interp.getType(instr.args[1].localIdx);

    assert (
        tX == Type.INT && tY == Type.INT,
        "invalid operand types in ovf op \"" ~ op ~ "\" (" ~ DataType.stringof ~ ")"
    );

    auto x = wX.intVal;
    auto y = wY.intVal;

    mixin(op);

    if (r >= DataType.min && r <= DataType.max)
    {
        interp.setSlot(
            instr.outSlot,
            Word.intv(cast(DataType)r),
            Type.INT
        );
    }
    else
    {
        interp.ip = instr.target.firstInstr;
    }
}

alias ArithOpOvf!(int32, Type.INT, "auto r = x + y;") op_add_i32_ovf;
alias ArithOpOvf!(int32, Type.INT, "auto r = x - y;") op_sub_i32_ovf;
alias ArithOpOvf!(int32, Type.INT, "auto r = x * y;") op_mul_i32_ovf;
alias ArithOpOvf!(int32, Type.INT, "auto r = x << y;") op_lsft_i32_ovf;

void CompareOp(DataType, Type typeTag, string op)(Interp interp, IRInstr instr)
{
    auto wX = interp.getWord(instr.args[0].localIdx);
    auto tX = interp.getType(instr.args[0].localIdx);
    auto wY = interp.getWord(instr.args[1].localIdx);
    auto tY = interp.getType(instr.args[1].localIdx);

    assert (
        tX == typeTag && tY == typeTag,
        "invalid operand types in op \"" ~ op ~ "\" (" ~ DataType.stringof ~ ")"
    );

    // Boolean result
    bool r;

    static if (typeTag == Type.INT)
    {
        auto x = cast(DataType)wX.intVal;
        auto y = cast(DataType)wY.intVal;
    }
    static if (typeTag == Type.FLOAT)
    {
        auto x = cast(DataType)wX.floatVal;
        auto y = cast(DataType)wY.floatVal;
    }

    mixin(op);        

    interp.setSlot(
        instr.outSlot,
        r? TRUE:FALSE,
        Type.CONST
    );
}

alias CompareOp!(int32, Type.INT, "r = (x == y);") op_eq_i32;
alias CompareOp!(int32, Type.INT, "r = (x != y);") op_ne_i32;
alias CompareOp!(int32, Type.INT, "r = (x < y);") op_lt_i32;
alias CompareOp!(int32, Type.INT, "r = (x > y);") op_gt_i32;
alias CompareOp!(int32, Type.INT, "r = (x <= y);") op_le_i32;
alias CompareOp!(int32, Type.INT, "r = (x >= y);") op_ge_i32;

alias CompareOp!(float64, Type.FLOAT, "r = (x == y);") op_eq_f64;
alias CompareOp!(float64, Type.FLOAT, "r = (x != y);") op_ne_f64;
alias CompareOp!(float64, Type.FLOAT, "r = (x < y);") op_lt_f64;
alias CompareOp!(float64, Type.FLOAT, "r = (x > y);") op_gt_f64;
alias CompareOp!(float64, Type.FLOAT, "r = (x <= y);") op_le_f64;
alias CompareOp!(float64, Type.FLOAT, "r = (x >= y);") op_ge_f64;

void LoadOp(DataType, Type typeTag)(Interp interp, IRInstr instr)
{
    auto wPtr = interp.getWord(instr.args[0].localIdx);
    auto tPtr = interp.getType(instr.args[0].localIdx);

    auto wOfs = interp.getWord(instr.args[1].localIdx);
    auto tOfs = interp.getType(instr.args[1].localIdx);

    assert (
        tPtr == Type.REFPTR || tPtr == Type.RAWPTR,
        "pointer is not pointer type in load op"
    );

    assert (
        tOfs == Type.INT,
        "offset is not integer type in load op"
    );

    auto ptr = wPtr.ptrVal;
    auto ofs = wOfs.intVal;

    auto val = *cast(DataType*)(ptr + ofs);

    Word word;

    static if (
        DataType.stringof == "byte"  ||
        DataType.stringof == "short" ||
        DataType.stringof == "int"   ||
        DataType.stringof == "long")
        word.intVal = val;

    static if (
        DataType.stringof == "ubyte"  ||
        DataType.stringof == "ushort" ||
        DataType.stringof == "uint"   ||
        DataType.stringof == "ulong")
        word.uintVal = val;

    static if (DataType.stringof == "double")
        word.floatVal = val;

    static if (
        DataType.stringof == "void*" ||
        DataType.stringof == "ubyte*")
        word.ptrVal = val;

    interp.setSlot(
        instr.outSlot,
        word,
        typeTag
    );
}

void StoreOp(DataType, Type typeTag, )(Interp interp, IRInstr instr)
{
    auto wPtr = interp.getWord(instr.args[0].localIdx);
    auto tPtr = interp.getType(instr.args[0].localIdx);

    auto wOfs = interp.getWord(instr.args[1].localIdx);
    auto tOfs = interp.getType(instr.args[1].localIdx);

    assert (
        tPtr == Type.REFPTR || tPtr == Type.RAWPTR,
        "pointer is not pointer type in store op"
    );

    assert (
        tOfs == Type.INT,
        "offset is not integer type in store op"
    );

    auto ptr = wPtr.ptrVal;
    auto ofs = wOfs.intVal;

    auto word = interp.getWord(instr.args[2].localIdx);

    DataType val;

    static if (
        DataType.stringof == "byte"  ||
        DataType.stringof == "short" ||
        DataType.stringof == "int"   ||
        DataType.stringof == "long")
        val = cast(DataType)word.intVal;

    static if (
        DataType.stringof == "ubyte"  ||
        DataType.stringof == "ushort" ||
        DataType.stringof == "uint"   ||
        DataType.stringof == "ulong")
        val = cast(DataType)word.uintVal;

    static if (DataType.stringof == "double")
        val = cast(DataType)word.floatVal;

    static if (
        DataType.stringof == "void*" ||
        DataType.stringof == "ubyte*")
        val = cast(DataType)word.ptrVal;

    *cast(DataType*)(ptr + ofs) = val;
}

alias LoadOp!(uint8, Type.INT) op_load_u8;
alias LoadOp!(uint16, Type.INT) op_load_u16;
alias LoadOp!(uint32, Type.INT) op_load_u32;
alias LoadOp!(float64, Type.FLOAT) op_load_f64;
alias LoadOp!(refptr, Type.REFPTR) op_load_refptr;
alias LoadOp!(rawptr, Type.RAWPTR) op_load_rawptr;

alias StoreOp!(uint8, Type.INT) op_store_u8;
alias StoreOp!(uint16, Type.INT) op_store_u16;
alias StoreOp!(uint32, Type.INT) op_store_u32;
alias StoreOp!(float64, Type.FLOAT) op_store_f64;
alias StoreOp!(refptr, Type.REFPTR) op_store_refptr;
alias StoreOp!(rawptr, Type.RAWPTR) op_store_rawptr;

void op_jump(Interp interp, IRInstr instr)
{
    interp.ip = instr.target.firstInstr;
}

void op_jump_true(Interp interp, IRInstr instr)
{
    auto valIdx = instr.args[0].localIdx;
    auto wVal = interp.getWord(valIdx);

    if (wVal == TRUE)
        interp.ip = instr.target.firstInstr;
}

void op_jump_false(Interp interp, IRInstr instr)
{
    auto valIdx = instr.args[0].localIdx;
    auto wVal = interp.getWord(valIdx);

    if (wVal == FALSE)
        interp.ip = instr.target.firstInstr;
}

void op_call(Interp interp, IRInstr instr)
{
    auto closIdx = instr.args[0].localIdx;
    auto thisIdx = instr.args[1].localIdx;

    auto wClos = interp.getWord(closIdx);
    auto tClos = interp.getType(closIdx);

    auto wThis = interp.getWord(thisIdx);
    auto tThis = interp.getType(thisIdx);

    assert (
        tClos == Type.REFPTR,
        "closure is not ref ptr"
    );

    // Get the function object from the closure
    auto closPtr = interp.getWord(closIdx).ptrVal;
    auto fun = cast(IRFunction)clos_get_fptr(closPtr);

    assert (
        fun !is null, 
        "null IRFunction pointer"
    );

    // If the function is not yet compiled, compile it now
    if (fun.entryBlock is null)
    {
        astToIR(fun.ast, fun);
    }

    // Set the caller instruction as the return address
    auto retAddr = cast(rawptr)instr;

    // Push the hidden call arguments
    interp.push(Word.ptrv(retAddr), Type.RAWPTR);       // Return address
    interp.push(Word.ptrv(closPtr), Type.REFPTR);       // Closure argument
    interp.push(wThis, tThis);                          // This argument

    auto numArgs = instr.args.length - 2;

    // Push the non-hidden function arguments
    for (size_t i = 0; i < numArgs; ++i)
    {
        auto argSlot = instr.args[2+i].localIdx + i + NUM_HIDDEN_ARGS;
        auto wArg = interp.getWord(argSlot);
        auto tArg = interp.getType(argSlot);
        interp.push(wArg, tArg);
    }

    // Push the argument count
    interp.push(Word.intv(numArgs), Type.INT);

    // Set the instruction pointer
    interp.ip = fun.entryBlock.firstInstr;
}

/// JavaScript new operator (constructor call)
void op_call_new(Interp interp, IRInstr instr)
{
    auto closIdx = instr.args[0].localIdx;

    // Get the function object from the closure
    auto closPtr = interp.getWord(closIdx).ptrVal;
    auto fun = cast(IRFunction)clos_get_fptr(closPtr);
    assert (
        fun !is null, 
        "null IRFunction pointer"
    );

    // Lookup the "prototype" property on the closure
    auto protoPtr = getProp(
        interp, 
        closPtr,
        getString(interp, "prototype")
    );

    // Allocate the "this" object
    auto thisPtr = newObj(
        interp, 
        &fun.classPtr, 
        protoPtr.word.ptrVal,
        CLASS_INIT_SIZE,
        2
    );

    // Set the this object pointer in the output slot
    interp.setSlot(
        instr.outSlot, 
        Word.ptrv(thisPtr),
        Type.REFPTR
    );

    // If the function is not yet compiled, compile it now
    if (fun.entryBlock is null)
    {
        astToIR(fun.ast, fun);
    }

    // Set the caller instruction as the return address
    auto retAddr = cast(rawptr)instr;

    // Push the hidden call arguments
    interp.push(Word.ptrv(retAddr), Type.RAWPTR);       // Return address
    interp.push(Word.ptrv(closPtr), Type.REFPTR);       // Closure argument
    interp.push(Word.ptrv(thisPtr), Type.REFPTR);       // This argument

    auto numArgs = instr.args.length - 1;

    // Push the non-hidden function arguments
    for (size_t i = 0; i < numArgs; ++i)
    {
        auto argSlot = instr.args[1+i].localIdx + i + NUM_HIDDEN_ARGS;
        auto wArg = interp.getWord(argSlot);
        auto tArg = interp.getType(argSlot);
        interp.push(wArg, tArg);
    }

    // Push the argument count
    interp.push(Word.intv(numArgs), Type.INT);

    // Set the instruction pointer
    interp.ip = fun.entryBlock.firstInstr;
}

/// Allocate/adjust the stack frame on function entry
void op_push_frame(Interp interp, IRInstr instr)
{
    auto numParams = instr.fun.params.length;
    auto numLocals = instr.fun.numLocals;

    // Get the number of arguments passed
    auto numArgs = interp.getWord(0).intVal;

    // If there are not enough arguments
    if (numArgs < numParams)
    {
        auto deltaArgs = numParams - numArgs;

        // Allocate new stack slots for the missing arguments
        interp.push(deltaArgs);

        // Move the argument count to the top of the stack
        interp.move(deltaArgs, 0);

        // Initialize the missing arguments to undefined
        for (size_t i = 0; i < deltaArgs; ++i)
            interp.setSlot(1 + i, UNDEF, Type.CONST);
    }

    // If there are too many arguments
    else if (numArgs > numParams)
    {
        auto deltaArgs = numArgs - numParams;

        // Move the argument count down
        interp.move(0, deltaArgs);

        // Remove superfluous argument slots
        interp.pop(deltaArgs);
    }

    // Allocate slots for the local variables
    auto delta = numLocals - (numParams + NUM_HIDDEN_ARGS + 1);
    //writefln("push_frame adding %s slot", delta);
    interp.push(delta);
}

void op_ret(Interp interp, IRInstr instr)
{
    auto retSlot   = instr.args[0].localIdx;
    auto raSlot    = instr.fun.raSlot;
    auto numLocals = instr.fun.numLocals;

    // Get the return value
    auto wRet = interp.wsp[retSlot];
    auto tRet = interp.tsp[retSlot];

    // Get the calling instruction
    auto callInstr = cast(IRInstr)interp.getWord(raSlot).ptrVal;

    // If the call instruction is valid
    if (callInstr !is null)
    {
        // If this is a new call and the return value is undefined
        if (callInstr.opcode == &CALL_NEW && wRet == UNDEF)
        {
            // Use the this value as the return value
            wRet = interp.getWord(instr.fun.thisSlot);
            tRet = interp.getType(instr.fun.thisSlot);
        }

        // Pop all local stack slots
        interp.pop(numLocals);

        // Set the instruction pointer to the post-call instruction
        interp.ip = callInstr.next;

        // Leave the return value in the call's return slot
        interp.setSlot(
            callInstr.outSlot, 
            wRet,
            tRet
        );
    }
    else
    {
        // Pop all local stack slots
        interp.pop(numLocals);

        // Terminate the execution
        interp.ip = null;

        // Leave the return value on top of the stack
        interp.push(wRet, tRet);
    }
}

void op_heap_alloc(Interp interp, IRInstr instr)
{
    auto wSize = interp.getWord(instr.args[0].localIdx);
    auto tSize = interp.getType(instr.args[0].localIdx);

    assert (
        tSize == Type.INT,
        "invalid size type"
    );

    assert (
        wSize.intVal > 0,
        "size must be positive"
    );

    auto ptr = interp.alloc(wSize.intVal);

    interp.setSlot(
        instr.outSlot,
        Word.ptrv(ptr),
        Type.REFPTR
    );
}

void op_get_str(Interp interp, IRInstr instr)
{
    auto wStr = interp.getWord(instr.args[0].localIdx);
    auto tStr = interp.getType(instr.args[0].localIdx);

    assert (
        valIsString(wStr, tStr),
        "expected string in get_str"
    );

    auto ptr = wStr.ptrVal;

    // Compute and set the hash code for the string
    auto hashCode = compStrHash(ptr);
    str_set_hash(ptr, hashCode);

    // Find the corresponding string in the string table
    ptr = getTableStr(interp, ptr);

    interp.setSlot(
        instr.outSlot,
        Word.ptrv(ptr),
        Type.REFPTR
    );
}

void op_print_str(Interp interp, IRInstr instr)
{
    auto wStr = interp.getWord(instr.args[0].localIdx);
    auto tStr = interp.getType(instr.args[0].localIdx);

    assert (
        valIsString(wStr, tStr),
        "expected string in print_str"
    );

    auto ptr = wStr.ptrVal;

    auto len = str_get_len(ptr);
    wchar[] wchars = new wchar[len];
    for (uint32 i = 0; i < len; ++i)
        wchars[i] = str_get_data(ptr, i);

    auto str = to!string(wchars);

    // Print the string to standard output
    write(str);
}

// ===========================================================================
// TODO: translate to runtime functions


void opAdd(Interp interp, IRInstr instr)
{
    auto idx0 = instr.args[0].localIdx;
    auto idx1 = instr.args[1].localIdx;
    auto w0 = interp.getWord(idx0);
    auto w1 = interp.getWord(idx1);
    auto t0 = interp.getType(idx0);
    auto t1 = interp.getType(idx1);

    // If both values are integer
    if (t0 == Type.INT && t1 == Type.INT)
    {
        interp.setSlot(
            instr.outSlot, 
            w0.intVal + w1.intVal
        );
    }

    // If either value is floating-point or integer
    else if (
        (t0 == Type.FLOAT || t0 == Type.INT) &&
        (t1 == Type.FLOAT || t1 == Type.INT))
    {
        auto f0 = (t0 == Type.FLOAT)? w0.floatVal:cast(float64)w0.intVal;
        auto f1 = (t1 == Type.FLOAT)? w1.floatVal:cast(float64)w1.intVal;

        interp.setSlot(
            instr.outSlot,
            f0 + f1
        );
    }

    // If either value is a string
    else if (valIsString(w0, t0) || valIsString(w1, t1))
    {
        // Evaluate the string value of both arguments
        auto s0 = interp.stringVal(w0, t0);
        auto s1 = interp.stringVal(w1, t1);

        auto l0 = str_get_len(s0);
        auto l1 = str_get_len(s1);

        auto sO = str_alloc(interp, l0+l1);

        for (uint32 i = 0; i < l0; ++i)
            str_set_data(sO, i, str_get_data(s0, i));
        for (uint32 i = 0; i < l1; ++i)
            str_set_data(sO, l0+i, str_get_data(s1, i));

        compStrHash(sO);
        sO = getTableStr(interp, sO);

        interp.setSlot(
            instr.outSlot, 
            Word.ptrv(sO),
            Type.REFPTR
        );
    }

    else
    {
        assert (false, "unsupported types in add");
    }
}

void opSub(Interp interp, IRInstr instr)
{
    auto idx0 = instr.args[0].localIdx;
    auto idx1 = instr.args[1].localIdx;
    auto w0 = interp.getWord(idx0);
    auto w1 = interp.getWord(idx1);
    auto t0 = interp.getType(idx0);
    auto t1 = interp.getType(idx1);

    // If both values are integer
    if (t0 == Type.INT && t1 == Type.INT)
    {
        interp.setSlot(
            instr.outSlot,
            w0.intVal - w1.intVal
        );
    }

    // If either value is floating-point or integer
    else if (
        (t0 == Type.FLOAT || t0 == Type.INT) &&
        (t1 == Type.FLOAT || t1 == Type.INT))
    {
        auto f0 = (t0 == Type.FLOAT)? w0.floatVal:cast(float64)w0.intVal;
        auto f1 = (t1 == Type.FLOAT)? w1.floatVal:cast(float64)w1.intVal;

        interp.setSlot(
            instr.outSlot, 
            f0 - f1
        );
    }

    else
    {
        assert (false, "unsupported types in sub");
    }
}

void opMul(Interp interp, IRInstr instr)
{
    auto idx0 = instr.args[0].localIdx;
    auto idx1 = instr.args[1].localIdx;
    auto w0 = interp.getWord(idx0);
    auto w1 = interp.getWord(idx1);
    auto t0 = interp.getType(idx0);
    auto t1 = interp.getType(idx1);

    // If both values are integer
    if (t0 == Type.INT && t1 == Type.INT)
    {
        interp.setSlot(
            instr.outSlot,
            w0.intVal * w1.intVal
        );
    }

    // If either value is floating-point or integer
    else if (
        (t0 == Type.FLOAT || t0 == Type.INT) &&
        (t1 == Type.FLOAT || t1 == Type.INT))
    {
        auto f0 = (t0 == Type.FLOAT)? w0.floatVal:cast(float64)w0.intVal;
        auto f1 = (t1 == Type.FLOAT)? w1.floatVal:cast(float64)w1.intVal;

        interp.setSlot(
            instr.outSlot, 
            f0 * f1
        );
    }

    else
    {
        assert (false, "unsupported types in mul");
    }
}

void opDiv(Interp interp, IRInstr instr)
{
    auto idx0 = instr.args[0].localIdx;
    auto idx1 = instr.args[1].localIdx;
    auto w0 = interp.getWord(idx0);
    auto w1 = interp.getWord(idx1);
    auto t0 = interp.getType(idx0);
    auto t1 = interp.getType(idx1);

    auto f0 = (t0 == Type.FLOAT)? w0.floatVal:cast(float64)w0.intVal;
    auto f1 = (t1 == Type.FLOAT)? w1.floatVal:cast(float64)w1.intVal;

    assert (
        (t0 == Type.INT || t0 == Type.FLOAT) ||
        (t1 == Type.INT || t1 == Type.FLOAT),
        "unsupported type in div"
    );

    // TODO: produce NaN or Inf on 0
    if (f1 == 0)
        throw new Error("division by 0");

    interp.setSlot(
        instr.outSlot, 
        f0 / f1
    );
}

void opMod(Interp interp, IRInstr instr)
{
    // TODO: support for other types
    auto idx0 = instr.args[0].localIdx;
    auto idx1 = instr.args[1].localIdx;

    auto w0 = interp.getWord(idx0);
    auto w1 = interp.getWord(idx1);

    // TODO: produce NaN or Inf on 0
    if (w1.intVal == 0)
        throw new Error("modulo with 0 divisor");

    interp.setSlot(
        instr.outSlot, 
        Word.intv(w0.intVal % w1.intVal),
        Type.INT
    );
}

void opTypeOf(Interp interp, IRInstr instr)
{
    auto idx = instr.args[0].localIdx;

    auto w = interp.getWord(idx);
    auto t = interp.getType(idx);

    refptr output;

    switch (t)
    {
        case Type.REFPTR:
        if (valIsString(w, t))
            output = getString(interp, "string");
        else
            assert (false, "unsupported type in typeof");
        break;

        case Type.INT:
        case Type.FLOAT:
        output = getString(interp, "number");
        break;

        case Type.CONST:
        if (w == TRUE)
            output = getString(interp, "boolean");
        else if (w == FALSE)
            output = getString(interp, "boolean");
        else if (w == NULL)
            output = getString(interp, "object");
        else if (w == UNDEF)
            output = getString(interp, "undefined");
        else
            assert (false, "unsupported constant");
        break;

        default:
        assert (false, "unsupported type in typeof");
    }

    interp.setSlot(
        instr.outSlot, 
        Word.ptrv(output),
        Type.REFPTR
    );
}

void opBoolVal(Interp interp, IRInstr instr)
{
    auto idx = instr.args[0].localIdx;

    auto w = interp.getWord(idx);
    auto t = interp.getType(idx);

    bool output;
    switch (t)
    {
        case Type.CONST:
        output = (w == TRUE);
        break;

        case Type.INT:
        output = (w.intVal != 0);
        break;

        case Type.REFPTR:
        if (valIsString(w, t))
            output = (str_get_len(w.ptrVal) > 0);
        else
            output = true;
        break;

        default:
        assert (false, "unsupported type in opBoolVal");
    }

    interp.setSlot(
        instr.outSlot, 
        output? TRUE:FALSE,
        Type.CONST
    );
}

void opCmpSe(Interp interp, IRInstr instr)
{
    // TODO: support for other types
    auto idx0 = instr.args[0].localIdx;
    auto idx1 = instr.args[1].localIdx;

    auto w0 = interp.getWord(idx0);
    auto w1 = interp.getWord(idx1);

    bool output = (w0.intVal == w1.intVal);

    interp.setSlot(
        instr.outSlot, 
        output? TRUE:FALSE,
        Type.CONST
    );
}

void opCmpLt(Interp interp, IRInstr instr)
{
    auto idx0 = instr.args[0].localIdx;
    auto idx1 = instr.args[1].localIdx;
    auto w0 = interp.getWord(idx0);
    auto w1 = interp.getWord(idx1);
    auto t0 = interp.getType(idx0);
    auto t1 = interp.getType(idx1);

    // If both values are integer
    if (t0 == Type.INT && t1 == Type.INT)
    {
        interp.setSlot(
            instr.outSlot,
            w0.intVal < w1.intVal
        );
    }

    // If either value is floating-point or integer
    else if (
        (t0 == Type.FLOAT || t0 == Type.INT) &&
        (t1 == Type.FLOAT || t1 == Type.INT))
    {
        auto f0 = (t0 == Type.FLOAT)? w0.floatVal:cast(float64)w0.intVal;
        auto f1 = (t1 == Type.FLOAT)? w1.floatVal:cast(float64)w1.intVal;

        interp.setSlot(
            instr.outSlot, 
            f0 < f1
        );
    }

    else
    {
        assert (false, "unsupported types in mul");
    }
}

/// Expression evaluation delegate function
alias refptr delegate(
    Interp interp, 
    refptr classPtr, 
    uint32 allocNumProps
) ObjAllocFn;

refptr newExtObj(
    Interp interp, 
    refptr* ppClass, 
    refptr protoPtr, 
    uint32 classInitSize,
    uint32 allocNumProps,
    ObjAllocFn objAllocFn
)
{
    auto classPtr = *ppClass;

    // If the class is not yet allocated
    if (classPtr is null)
    {
        // Lazily allocate the class
        classPtr = class_alloc(interp, classInitSize);
        class_set_id(classPtr, 0);

        // Update the instruction's class pointer
        *ppClass = classPtr;
    }    
    else
    {
        // Get the number of properties to allocate from the class
        allocNumProps = max(class_get_num_props(classPtr), allocNumProps);
    }

    // Allocate the object
    auto objPtr = objAllocFn(interp, classPtr, allocNumProps);

    // Initialize the object
    obj_set_class(objPtr, classPtr);
    obj_set_proto(objPtr, protoPtr);

    return objPtr;
}

refptr newObj(
    Interp interp, 
    refptr* ppClass, 
    refptr protoPtr, 
    uint32 classInitSize,
    uint32 allocNumProps
)
{
    return newExtObj(
        interp, 
        ppClass, 
        protoPtr, 
        classInitSize,
        allocNumProps,
        delegate refptr(Interp interp, refptr classPtr, uint32 allocNumProps)
        {
            auto objPtr = obj_alloc(interp, allocNumProps);
            return objPtr;
        }
    );
}

refptr newArr(
    Interp interp, 
    refptr* ppClass, 
    refptr protoPtr, 
    uint32 classInitSize,
    uint32 allocNumElems
)
{
    return newExtObj(
        interp, 
        ppClass, 
        protoPtr, 
        classInitSize,
        0,
        delegate refptr(Interp interp, refptr classPtr, uint32 allocNumProps)
        {
            auto objPtr = arr_alloc(interp, allocNumProps);
            auto tblPtr = arrtbl_alloc(interp, allocNumElems);
            arr_set_tbl(objPtr, tblPtr);
            arr_set_len(objPtr, 0);
            return objPtr;
        }
    );
}

refptr newClos(
    Interp interp, 
    refptr* ppClass, 
    refptr protoPtr, 
    uint32 classInitSize,
    uint32 allocNumProps,
    uint32 allocNumCells,
    IRFunction fun
)
{
    return newExtObj(
        interp, 
        ppClass, 
        protoPtr, 
        classInitSize,
        allocNumProps,
        delegate refptr(Interp interp, refptr classPtr, uint32 allocNumProps)
        {
            auto objPtr = clos_alloc(interp, allocNumProps, allocNumCells);
            clos_set_fptr(objPtr, cast(rawptr)fun);
            return objPtr;
        }
    );
}

void setProp(Interp interp, refptr objPtr, refptr propStr, ValuePair val)
{
    // Follow the next link chain
    for (;;)
    {
        auto nextPtr = obj_get_next(objPtr);
        if (nextPtr is null)
            break;
         objPtr = nextPtr;
    }

    // Get the number of class properties
    auto classPtr = obj_get_class(objPtr);
    auto numProps = class_get_num_props(classPtr);

    // Look for the property in the class
    uint32 propIdx;
    for (propIdx = 0; propIdx < numProps; ++propIdx)
    {
        auto nameStr = class_get_prop_name(classPtr, propIdx);
        if (propStr == nameStr)
            break;
    }

    // If this is a new property
    if (propIdx == numProps)
    {
        //writefln("new property");

        // TODO: implement class extension
        auto classCap = class_get_cap(classPtr);
        assert (propIdx < classCap, "class capacity exceeded");

        // Set the property name
        class_set_prop_name(classPtr, propIdx, propStr);

        // Increment the number of properties in this class
        class_set_num_props(classPtr, numProps + 1);
    }

    //writefln("num props after write: %s", class_get_num_props(interp.globalClass));
    //writefln("prop idx: %s", propIdx);
    //writefln("intval: %s", wVal.intVal);

    // Get the length of the object
    auto objCap = obj_get_cap(objPtr);

    // If the object needs to be extended
    if (propIdx >= objCap)
    {
        //writeln("*** extending object ***");

        auto objType = obj_get_header(objPtr);

        refptr newObj;

        // Switch on the layout type
        switch (objType)
        {
            case LAYOUT_OBJ:
            newObj = obj_alloc(interp, objCap+1);
            break;

            case LAYOUT_CLOS:
            auto numCells = clos_get_num_cells(objPtr);
            newObj = clos_alloc(interp, objCap+1, numCells);
            clos_set_fptr(newObj, clos_get_fptr(objPtr));
            for (uint32 i = 0; i < numCells; ++i)
                clos_set_cell(newObj, i, clos_get_cell(objPtr, i));
            break;

            default:
            assert (false, "unhandled object type");
        }

        obj_set_class(newObj, classPtr);
        obj_set_proto(newObj, obj_get_proto(objPtr));

        // Copy over the property words and types
        for (uint32 i = 0; i < objCap; ++i)
        {
            obj_set_word(newObj, i, obj_get_word(objPtr, i));
            obj_set_type(newObj, i, obj_get_type(objPtr, i));
        }

        // Set the next pointer in the old object
        obj_set_next(objPtr, newObj);

        // Update the object pointer
        objPtr = newObj;
    }

    // Set the value and its type in the object
    obj_set_word(objPtr, propIdx, val.word.intVal);
    obj_set_type(objPtr, propIdx, val.type);
}

ValuePair getProp(Interp interp, refptr objPtr, refptr propStr)
{
    // Follow the next link chain
    for (;;)
    {
        auto nextPtr = obj_get_next(objPtr);
        if (nextPtr is null)
            break;
         objPtr = nextPtr;
    }

    // Get the number of class properties
    auto classPtr = obj_get_class(objPtr);
    auto numProps = class_get_num_props(classPtr);

    // Look for the property in the global class
    uint32 propIdx;
    for (propIdx = 0; propIdx < numProps; ++propIdx)
    {
        auto nameStr = class_get_prop_name(classPtr, propIdx);
        if (propStr == nameStr)
            break;
    }

    // If the property was not found
    if (propIdx == numProps)
    {
        auto protoPtr = obj_get_proto(objPtr);

        // If the prototype is null, produce undefined
        if (protoPtr is NULL.ptrVal)
            return ValuePair(UNDEF, Type.CONST);

        // Do a recursive lookup on the prototype
        return getProp(
            interp,
            protoPtr,
            propStr
        );
    }

    //writefln("num props after write: %s", class_get_num_props(interp.globalClass));
    //writefln("prop idx: %s", propIdx);

    auto pWord = obj_get_word(objPtr, propIdx);
    auto pType = cast(Type)obj_get_type(objPtr, propIdx);

    return ValuePair(Word.intv(pWord), pType);
}

/**
Set an element of an array
*/
void setArrElem(Interp interp, refptr arr, uint32 index, ValuePair val)
{
    // Get the array length
    auto len = arr_get_len(arr);

    // Get the array table
    auto tbl = arr_get_tbl(arr);

    // If the index is outside the current size of the array
    if (index >= len)
    {
        // Compute the new length
        auto newLen = index + 1;

        //writefln("extending array to %s", newLen);

        // Get the array capacity
        auto cap = arrtbl_get_cap(tbl);

        // If the new length would exceed the capacity
        if (newLen > cap)
        {
            // Compute the new size to resize to
            auto newSize = 2 * cap;
            if (newLen > newSize)
                newSize = newLen;

            // Extend the internal table
            tbl = extArrTable(interp, arr, tbl, len, cap, newSize);
        }

        // Update the array length
        arr_set_len(arr, newLen);
    }

    // Set the element in the array
    arrtbl_set_word(tbl, index, val.word.intVal);
    arrtbl_set_type(tbl, index, val.type);
}

/**
Extend the internal array table of an array
*/
refptr extArrTable(
    Interp interp, 
    refptr arr, 
    refptr curTbl, 
    uint32 curLen, 
    uint32 curSize, 
    uint32 newSize
)
{
    // Allocate the new table without initializing it, for performance
    auto newTbl = arrtbl_alloc(interp, newSize);

    // Copy elements from the old table to the new
    for (uint32 i = 0; i < curLen; i++)
    {
        arrtbl_set_word(newTbl, i, arrtbl_get_word(curTbl, i));
        arrtbl_set_type(newTbl, i, arrtbl_get_type(curTbl, i));
    }

    // Initialize the remaining table entries to undefined
    for (uint32 i = curLen; i < newSize; i++)
    {
        arrtbl_set_word(newTbl, i, UNDEF.intVal);
        arrtbl_set_type(newTbl, i, Type.CONST);
    }

    // Update the table reference in the array
    arr_set_tbl(arr, newTbl);

    return newTbl;
}

/**
Get an element from an array
*/
ValuePair getArrElem(Interp interp, refptr arr, uint32 index)
{
    auto len = arr_get_len(arr);

    //writefln("cur len %s", len);

    if (index >= len)
        return ValuePair(UNDEF, Type.CONST);

    auto tbl = arr_get_tbl(arr);

    return ValuePair(
        Word.intv(arrtbl_get_word(tbl, index)),
        cast(Type)arrtbl_get_type(tbl, index),
    );
}

/// Create a new blank object
void opNewObj(Interp interp, IRInstr instr)
{
    auto numProps = max(instr.args[0].intVal, 2);
    auto ppClass  = &instr.args[1].ptrVal;

    // Allocate the object
    auto objPtr = newObj(
        interp, 
        ppClass, 
        NULL.ptrVal,    // FIXME: object prototype
        CLASS_INIT_SIZE,
        cast(uint)numProps
    );

    interp.setSlot(
        instr.outSlot,
        Word.ptrv(objPtr),
        Type.REFPTR
    );
}

/// Create a new uninitialized array
void opNewArr(Interp interp, IRInstr instr)
{
    auto numElems = max(instr.args[0].intVal, 2);
    auto ppClass  = &instr.args[1].ptrVal;

    // Allocate the array
    auto arrPtr = newArr(
        interp, 
        ppClass, 
        NULL.ptrVal,    // FIXME: array prototype
        CLASS_INIT_SIZE,
        cast(uint)numElems
    );

    interp.setSlot(
        instr.outSlot,
        Word.ptrv(arrPtr),
        Type.REFPTR
    );
}

void opNewClos(Interp interp, IRInstr instr)
{
    auto fun = instr.args[0].fun;

    // TODO
    // TODO: num clos cells, can get this from fun object!
    // TODO

    // Allocate the prototype object
    auto objPtr = newObj(
        interp, 
        &instr.args[1].ptrVal, 
        NULL.ptrVal,        // TODO: object proto
        CLASS_INIT_SIZE,
        0
    );

    // Allocate the closure object
    auto closPtr = newClos(
        interp, 
        &instr.args[2].ptrVal, 
        NULL.ptrVal,        // TODO: function proto
        CLASS_INIT_SIZE,
        1,
        0,                  // TODO: num cells
        fun
    );

    // Set the prototype property on the closure object
    setProp(
        interp, 
        closPtr,
        getString(interp, "prototype"),
        ValuePair(Word.ptrv(objPtr), Type.REFPTR)
    );
   
    // Output a pointer to the closure
    interp.setSlot(
        instr.outSlot,
        Word.ptrv(closPtr),
        Type.REFPTR
    );    
}

/// Set an object property value
void opSetProp(Interp interp, IRInstr instr)
{
    auto base = interp.getSlot(instr.args[0].localIdx);
    auto prop = interp.getSlot(instr.args[1].localIdx);
    auto val  = interp.getSlot(instr.args[2].localIdx);

    if (base.type == Type.REFPTR)
    {
        auto objPtr = base.word.ptrVal;
        auto type = obj_get_header(objPtr);

        if (type == LAYOUT_ARR)
        {
            // TODO: toUint32?
            assert (prop.type == Type.INT, "prop type should be int");
            auto index = prop.word.intVal;

            setArrElem(
                interp,
                objPtr,
                cast(uint32)index,
                val
            );
        }
        else
        {
            // TODO: toString
            assert (prop.type == Type.REFPTR, "prop type should be string");
            auto propStr = prop.word.ptrVal;

            setProp(
                interp,
                objPtr,
                propStr,
                val
            );
        }
    }
    else
    {
        // TODO: handle null, undef base
        // TODO: toObject
        assert (false, "invalid base in setProp");
    }
}

/// Get an object property value
void opGetProp(Interp interp, IRInstr instr)
{
    auto base = interp.getSlot(instr.args[0].localIdx);
    auto prop = interp.getSlot(instr.args[1].localIdx);

    ValuePair val;

    if (base.type == Type.REFPTR)
    {
        auto objPtr = base.word.ptrVal;
        auto type = obj_get_header(objPtr);

        if (type == LAYOUT_ARR)
        {
            // TODO: toUint32?
            assert (prop.type == Type.INT, "prop type should be int");
            auto index = prop.word.intVal;

            val = getArrElem(
                interp,
                objPtr,
                cast(uint32)index
            );
        }
        else
        {
            // TODO: toString
            assert (prop.type == Type.REFPTR, "prop type should be string");
            auto propStr = prop.word.ptrVal;

            val = getProp(
                interp,
                objPtr,
                propStr
            );
        }
    }
    else
    {
        // TODO: handle null, undef base
        // TODO: toObject
        assert (false, "invalid base in setProp");
    }

    interp.setSlot(
        instr.outSlot,
        val
    );
}

/// Set a global variable
void opSetGlobal(Interp interp, IRInstr instr)
{
    auto prop = interp.getSlot(instr.args[0].localIdx);
    auto val  = interp.getSlot(instr.args[1].localIdx);

    assert (prop.type == Type.REFPTR, "invalid global property");
    auto propStr = prop.word.ptrVal;

    setProp(
        interp,
        interp.globalObj,
        propStr,
        val
    );
}

/// Get the value of a global variable
void opGetGlobal(Interp interp, IRInstr instr)
{
    auto prop = interp.getSlot(instr.args[0].localIdx);

    assert (prop.type == Type.REFPTR, "invalid global property");
    auto propStr = prop.word.ptrVal;

    ValuePair val = getProp(
        interp,
        interp.globalObj,
        propStr
    );

    interp.setSlot(
        instr.outSlot,
        val
    );
}

