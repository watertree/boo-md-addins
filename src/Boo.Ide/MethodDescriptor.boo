namespace Boo.Ide

import System

import Boo.Lang.Compiler.TypeSystem

class MethodDescriptor:
	[getter(Name)] _name as string
	[getter(Arguments)] _arguments as string*
	[getter(ReturnType)] _returnType as string
	
	def constructor(method as IMethod):
		_name = method.Name
		arguments = System.Collections.Generic.List of string()
		for param in method.GetParameters():
			arguments.Add("${param.Name} as ${param.Type}")
		_arguments = arguments
		_returnType = "${method.ReturnType}"
