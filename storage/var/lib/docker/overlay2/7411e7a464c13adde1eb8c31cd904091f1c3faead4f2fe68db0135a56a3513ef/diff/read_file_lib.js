'use strict';

const fs = require('fs');

const _NEW_LINE_CHAR_ = ['\n', '\r'];

class ReadFileBackwardsLib {
    constructor() {
        this.fd = -1;

        this.response = {
            data: [],
            lineCount: -1,
            linePosition: -1,
            error: ''
        };

        this.all_responses = [];
    }

    setFd(newFd) {
        this.fd = newFd;
    }

    getFd() {
        return this.fd;
    }

    setData(newData) {
        this.response.data = JSON.parse(JSON.stringify(newData));
    }

    setLineCount(newLineCount) {
        this.response.lineCount = newLineCount;
    }

    setLinePosition(newPosition) {
        this.response.linePosition = newPosition;
    }

    setError(err) {
        this.response.error = err;
    }

    getResponse() {
        return JSON.parse(JSON.stringify(this.response));
    }

    setAllResponses(res) {
        this.all_responses.push(res);
    }

    getAllResponses() {
        return JSON.parse(JSON.stringify(this.all_responses));
    }

    // Return a promise for opening the file
    openFilePromise(filePath) {
        return new Promise((resolve, reject) => {
            fs.open(filePath, (err, fd) => {
                if (err) {
                    reject(err);
                }
                resolve(fd);
            });
        });
    }

    // Return a promise for getting the file size which is the last line position
    fileStatsPromise(fd) {
        return new Promise((resolve, reject) => {
            fs.fstat(fd, (err, stats) => {
                if (err) {
                    reject(err);
                }
                resolve(stats.size);
            });
        });
    }

    // Return a promise for reading the log file based on line position and read direction
    // Read 1 character for each function execution
    readCharPromise(fd, lPos, dir) {
        return new Promise((resolve, reject) => {
            const pos = dir == 'backward' ? lPos - 1 : lPos + 1;
            fs.read(fd, Buffer.alloc(1), 0, 1, pos, (err, bytesRead, buffer) => {
                if (err) {
                    reject(err);
                }
                let newChar = buffer.toString('utf8');
                // If the buffer is not utf8 encoded, the toString() function will convert it to � (\uFFFD)
                if (newChar == '\uFFFD') {
                    // If the buffer read is not utf8 encoded, use hex instead
                    // '%' is added to convert it to URI encoding format 
                    // which can be decoded using decodeURIComponent function
                    newChar = '%' + buffer.toString('hex');
                    if (dir == 'backward') {
                        newChar = this.reverseString(newChar);
                    }
                }
                resolve(newChar);
            });
        });
    }

    // Reverse the characters in string
    reverseString(str) {
        let newStr = '';
        if (str.length > 0) {
            for (let i = str.length - 1; i >= 0; i--) {
                newStr += str[i];
            }
        }
        return newStr;
    }

    // Read all the lines according to the line count, line position and read direction
    async readLinePromise(lineCount, linePosition, direction, maxPosition) {
        try {
            let char = '';
            let line = '';
            let allLines = [];
            let lCount = 0;
            let lPos = linePosition == -1 ? (direction == 'backward' ? maxPosition : -1) : linePosition;
            // Validate the line position
            if ((lPos <= 0 && direction == 'backward') || (lPos >= maxPosition - 1 && direction == 'forward')) {
                throw new Error(`Invalid line position ${lPos} (max: ${maxPosition}) for reading file ${direction}`);
            }
            // Repeatedly read the log file until it reaches the specific amount of line count or reaches the start/end of file
            while (lCount < lineCount &&
                ((lPos > 0 && direction == 'backward') || (lPos < maxPosition - 1 && direction == 'forward'))) {
                char = await this.readCharPromise(this.getFd(), lPos, direction);
                lPos = direction == 'backward' ? lPos - 1 : lPos + 1;
                if (_NEW_LINE_CHAR_.includes(char)) {
                    if (line.length > 0) {
                        lCount = lCount + 1;
                        allLines.push(line);
                    }
                    line = '';
                    continue;
                }
                line += char;
            }
            // Push the last line when reaches the start/end of file
            if (line.length > 0) {
                lCount = lCount + 1;
                allLines.push(line);
            }
            // Set the line position to -1 if reached the end of file
            if (lPos >= maxPosition - 1) {
                lPos = -1;
            }
            // Reverse characters in each line in the array if read file backwards
            if (direction == 'backward') {
                for (let i = 0; i < allLines.length; i++) {
                    allLines[i] = this.reverseString(allLines[i]);
                }
            }
            return ({
                data: JSON.parse(JSON.stringify(allLines)),
                lineCount: lCount,
                linePosition: lPos
            });
        } catch (err) {
            throw new Error(err.message);
        }
    }
}

/*
The function "readFileFunc" is used to read a file in both forward and backward direction based on line count and line position
When the line position reach the start of file, 0 is returned.

@param  {string}  filePath - direct or relative path to file.
@param  {array}   countPosDir - an Array of JSON object that has "lineCount", "linePosition" and "direction" attributes
                                {int} lineCount - the number of lines need to be read
                                {int} linPosition - the position to start to read
                                {string} direction - the read direction, takes in "backward" or "forward" input only. 

@return {promise}   a promise resolved or rejected with an array of JSON object with attributes
                    "data", "lineCount", "linePosition" and "error", 
                    where "data" is the lines read,
                    "lineCount" is the number of lines read,
                    "linePosition" is the position of file after reading the number of lines required,
                    "error" is the error message
*/

module.exports = async function readFileFunc(filePath, countPosDir) {
    const lib = new ReadFileBackwardsLib();
    try {
        // Open the file
        lib.setFd(await lib.openFilePromise(filePath));

        // Get the last line position of the file
        const max = await lib.fileStatsPromise(lib.getFd());

        let readPromises = [];
        // Check for input data type and validity
        if (Array.isArray(countPosDir)) {
            if (countPosDir.length > 0) {
                for (let obj of countPosDir) {
                    if ('lineCount' in obj && 'linePosition' in obj && 'direction' in obj) {
                        obj.lineCount = typeof obj.lineCount === 'string' || obj.lineCount instanceof String ? parseInt(obj.lineCount) : obj.lineCount;
                        obj.linePosition = typeof obj.linePosition === 'string' || obj.linePosition instanceof String ? parseInt(obj.linePosition) : obj.linePosition;
                        // Push the promises into an array
                        readPromises.push(lib.readLinePromise(obj.lineCount, obj.linePosition, obj.direction, max));
                    } else {
                        throw new Error('Error in arguments. No lineCount, linePosition or direction.');
                    }
                }
                // Run all the read file promises concurrently
                const resolvedPromises = await Promise.all(readPromises);
                if (resolvedPromises.length > 0) {
                    for (let newData of resolvedPromises) {
                        lib.setData(newData.data);
                        lib.setLineCount(newData.lineCount);
                        lib.setLinePosition(newData.linePosition);
                        lib.setAllResponses(lib.getResponse());
                    }
                }
            } else {
                throw new Error('Empty arguments.');
            }
        } else {
            throw new Error('Error in arguments data type.');
        }
    } catch (e) {
        lib.setError(e.message);
        lib.setAllResponses(lib.getResponse());
    } finally {
        // Close the file
        if (lib.getFd() != -1) {
            fs.close(lib.getFd(), (err) => {
                if (err) {
                    console.log(err.message);
                }
            });
        }
        // Return response
        return lib.getAllResponses();
    }
}
