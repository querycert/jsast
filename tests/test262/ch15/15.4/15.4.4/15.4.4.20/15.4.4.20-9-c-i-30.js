/// Copyright (c) 2012 Ecma International.  All rights reserved. 
/// Ecma International makes this code available under the terms and conditions set
/// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the 
/// "Use Terms").   Any redistribution of this code must retain the above 
/// copyright and this notice and otherwise comply with the Use Terms.
/**
 * @path ch15/15.4/15.4.4/15.4.4.20/15.4.4.20-9-c-i-30.js
 * @description Array.prototype.filter - unnhandled exceptions happened in getter terminate iteration on an Array-like object
 */


function testcase() {

        var accessed = false;
        function callbackfn(val, idx, obj) {
            if (idx > 1) {
                accessed = true;
            }
            return true;
        }

        var obj = { 0: 11, 5: 10, 10: 8, length: 20 };
        Object.defineProperty(obj, "1", {
            get: function () {
                throw new RangeError("unhandle exception happened in getter");
            },
            configurable: true
        });

        try {
            Array.prototype.filter.call(obj, callbackfn);
            return false;
        } catch (ex) {
            return (ex instanceof RangeError) && !accessed;
        }
    }
runTestCase(testcase);
