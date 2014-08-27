/*
 * This code is adapted for Puzlet from Paper.js.
 * http://paperjs.org/
 *
 * Copyright (c) 2011 - 2014, Juerg Lehni & Jonathan Puckey
 * http://scratchdisk.com/ & http://jonathanpuckey.com/
 *
 * Distributed under the MIT license. See LICENSE file for details.
 *
 * All rights reserved.
 */

/* Puzlet notes
* Converted == and != to === and !== so they work with CoffeeScript.

*/

PaperScript = (function() {
	
	var scope = window;
	
	// Operators to overload
	
	var binaryOperators = {
		// The hidden math methods are to be injected specifically, see below.
		'+': '__add',
		'-': '__subtract',
		'*': '__multiply',
		'/': '__divide',
		'%': '__modulo',
		// MVC - no longer use the real equals.
		'===': '__equals',
		'!==': '__equals',
		// MVC - add inequalties
		'<': '__lt',
		'>': '__gt',
		'<=': '__leq',
		'>=': '__geq'
	};
	
	var unaryOperators = {
		'-': '__negate',
		'+': null
	};
	
	// Use very short name for the binary operator (_$_) as well as the
	// unary operator ($_), as operations will be replaced with then.
	// The underscores stands for the values, and the $ for the operators.
	
	// MVC - these can be defined outisde?
	
	// Binary Operator Handler
	function _$_(left, operator, right) {
		var handler = binaryOperators[operator];
		if (left && left[handler]) {
			var res = left[handler](right);
			return operator === '!==' ? !res : res;
		}
		switch (operator) {
		case '+': return left + right;
		case '-': return left - right;
		case '*': return left * right;
		case '/': return left / right;
		case '%': return left % right;
		case '===': return left === right;
		case '!==': return left !== right;
		// MVC - inequalities
		case '<': return left < right;
		case '>': return left > right;
		case '<=': return left <= right;
		case '>=': return left >= right;
		}
	}

	// Unary Operator Handler
	function $_(operator, value) {
		var handler = unaryOperators[operator];
		if (handler && value && value[handler])
			return value[handler]();
		switch (operator) {
		case '+': return +value;
		case '-': return -value;
		}
	}

	// AST Helpers

	/**
	 * Compiles PaperScript code into JavaScript code.
	 *
	 * @name PaperScript.compile
	 * @function
	 * @param {String} code The PaperScript code
	 * @return {String} the compiled PaperScript as JavaScript code
	 */
	function compile(code) {
		// Use Acorn or Esprima to translate the code into an AST structure
		// which is then walked and parsed for operators to overload. Instead of
		// modifying the AST and translating it back to code, we directly change 
		// the source code based on the parser's range information, to preserve
		// line-numbers in syntax errors and remove the need for Escodegen.

		// Track code insertions so their differences can be added to the
		// original offsets.
		var insertions = [];

		// Converts an original offset to the one in the current state of the 
		// modified code.
		function getOffset(offset) {
			// Add all insertions before this location together to calculate
			// the current offset
			for (var i = 0, l = insertions.length; i < l; i++) {
				var insertion = insertions[i];
				if (insertion[0] >= offset)
					break;
				offset += insertion[1];
			}
			return offset;
		}

		// Returns the node's code as a string, taking insertions into account.
		function getCode(node) {
			return code.substring(getOffset(node.range[0]),
					getOffset(node.range[1]));
		}

		// Replaces the node's code with a new version and keeps insertions
		// information up-to-date.
		function replaceCode(node, str) {
			var start = getOffset(node.range[0]),
				end = getOffset(node.range[1]),
				insert = 0;
			// Sort insertions by their offset, so getOffest() can do its thing
			for (var i = insertions.length - 1; i >= 0; i--) {
				if (start > insertions[i][0]) {
					insert = i + 1;
					break;
				}
			}
			insertions.splice(insert, 0, [start, str.length - end + start]);
			code = code.substring(0, start) + str + code.substring(end);
		}

		// Recursively walks the AST and replaces the code of certain nodes
		function walkAST(node, parent) {
			// MVC
			//console.log("parent/node", (parent ? parent.type : null), node);
			//if (node.type==="ExpressionStatement" && node.expression.callee.name==="oo") {
			//	console.log("***oo", parent);
			//}
			//if (node.type==="BlockStatement") {
			//	console.log("===block parent", parent);
			//}
			//
	
			if (!node)
				return;
			for (var key in node) {
				if (key === 'range')
					continue;
				var value = node[key];
				if (Array.isArray(value)) {
					for (var i = 0, l = value.length; i < l; i++)
						walkAST(value[i], node);
				} else if (value && typeof value === 'object') {
					// We cannot use Base.isPlainObject() for these since
					// Acorn.js uses its own internal prototypes now.
					walkAST(value, node);
				}
			}
			switch (node && node.type) {
			case 'UnaryExpression': // -a
				if (node.operator in unaryOperators
						&& node.argument.type !== 'Literal') {
					var arg = getCode(node.argument);
					replaceCode(node, '$_("' + node.operator + '", '
							+ arg + ')');
				}
				break;
			case 'BinaryExpression': // a + b, a - b, a / b, a * b, a === b, ...
				if (node.operator in binaryOperators
					&& (node.left.type !== 'Literal' || node.right.type !== 'Literal')) {  // Puzlet
				//if (node.operator in binaryOperators
				//		&& node.left.type !== 'Literal') {
					var left = getCode(node.left),
						right = getCode(node.right);
					replaceCode(node, '_$_(' + left + ', "' + node.operator
							+ '", ' + right + ')');
				}
				break;
			case 'UpdateExpression': // a++, a--
			case 'AssignmentExpression': /// a += b, a -= b
				if (!(parent && (
						// Filter out for statements to allow loop increments
						// to perform well
						parent.type === 'ForStatement'
						// We need to filter out parents that are comparison
						// operators, e.g. for situations like if (++i < 1),
						// as we can't replace that with if (_$_(i, "+", 1) < 1)
						// Match any operator beginning with =, !, < and >.
						|| parent.type === 'BinaryExpression'
							&& /^[=!<>]/.test(parent.operator)
						// array[i++] is a MemberExpression with computed = true
						// We can't replace that with array[_$_(i, "+", 1)].
						|| parent.type === 'MemberExpression'
							&& parent.computed))) {
					if (node.type === 'UpdateExpression') {
						if (!node.prefix) {
							var arg = getCode(node.argument);
							replaceCode(node, arg + ' = _$_(' + arg + ', "'
									+ node.operator[0] + '", 1)');
						}
					} else { // AssignmentExpression
						if (/^.=$/.test(node.operator)
							&& (node.left.type !== 'Literal' || node.right.type !== 'Literal')) {  // Puzlet
					//			&& node.left.type !== 'Literal') {
							var left = getCode(node.left),
								right = getCode(node.right);
							replaceCode(node, left + ' = _$_(' + left + ', "'
									+ node.operator[0] + '", ' + right + ')');
						}
					}
				}
				break;
			}
		}
		// Now do the parsing magic
		walkAST(scope.acorn.parse(code, { ranges: true }));
		return code;
	}
	
	return {
		compile: compile,
		_$_: _$_,
		$_: $_
	};
	
}).call(this);
