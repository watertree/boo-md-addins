namespace Boo.Ide

import System

import Boo.Lang.Compiler.TypeSystem

class MethodDescriptor:
	[getter(Name)] _name as string
	[getter(Arguments)] _arguments as string*
	[getter(ReturnType)] _returnType as string
	
	def constructor(method as IMethod):
		_name = method.Name
		_arguments = List of string("${param.Name} as ${param.Type}" for param in method.GetParameters())
		_returnType = "${method.ReturnType}"
