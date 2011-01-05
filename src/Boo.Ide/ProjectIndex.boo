namespace Boo.Ide

import Boo.Lang.Environments
import Boo.Lang.Compiler
import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.TypeSystem

import Boo.Adt

let SendErrorsToTheConsole = true

class ProjectIndex:
	
	_compiler as BooCompiler
	_parser as BooCompiler
	
	_modules = List of Module()
	_implicitNamespaces as List
	_contexts = System.Collections.Generic.Dictionary[of string, CompilerContext]()
		
	def constructor():
		_compiler = BooCompiler()
		_compiler.Parameters.Pipeline = Pipelines.ResolveExpressions(BreakOnErrors: false)
		
		_parser = BooCompiler()
		_parser.Parameters.Pipeline = Pipelines.Parse() { Steps.IntroduceModuleClasses() }
		_implicitNamespaces = ["Boo.Lang", "Boo.Lang.Builtins"]
	
	def constructor(compiler as BooCompiler, parser as BooCompiler, implicitNamespaces as List):
		_compiler = compiler
		_parser = parser
		_implicitNamespaces = implicitNamespaces
		
	[lock]
	virtual def Parse(fileName as string, code as string):
		return ParseModule(CompileUnit(), fileName, code)
		
	[lock]
	virtual def ProposalsFor(fileName as string, code as string):
		result = {}
		
		ReplaceModule(fileName, code) do (context, module):
			ActiveEnvironment.With(context.Environment) do:
				expression = CursorLocationFinder().FindIn(module)
				if not expression is null:
					for proposal in CompletionProposer.ForExpression(expression):
						result.Add(proposal.Name, proposal)
		
		tmpUnit = CompileUnit()
		module = ParseModule(tmpUnit, fileName, code)
		ActiveEnvironment.With(_compiler.Run(tmpUnit).Environment) do:
			expression = CursorLocationFinder().FindIn(module)
			if not expression is null:
				for proposal in CompletionProposer.ForExpression(expression):
					result[proposal.Name] = proposal
			
		return array(CompletionProposal,result.Values)
		
	[lock]
	virtual def MethodsFor(fileName as string, code as string, methodName as string, methodLine as int):
		methods = System.Collections.Generic.List of MethodDescriptor()
		
		ReplaceModule(fileName, code) do(context, module):
			ActiveEnvironment.With(context.Environment) do:
				expression = MethodInvocationFinder(methodName, fileName, methodLine).FindIn(module)
				if expression is null:
					print "No method found for ${methodName}: (${fileName}:${methodLine})"
					return
				if (expression.Target.Entity isa Ambiguous):
					# Multiple overloads
					for i in (expression.Target.Entity as Ambiguous).Entities:
						methods.Add (MethodDescriptor(i))
				elif (expression.Target.Entity isa IMethod):
					# May have failed resolution - try one more time
					entity = Services.NameResolutionService().ResolveMethod((expression.Target.Entity as IMethod).DeclaringType, methodName)
					if (entity isa Ambiguous):
						# Multiple overloads
						for i in (expression.Target.Entity as Ambiguous).Entities:
							methods.Add (MethodDescriptor(i))
					else:
						# No overloads
						methods.Add(MethodDescriptor(entity))
		return methods
		
	[lock]
	virtual def LocalsAt(fileName as string, code as string, line as int):
		locals = System.Collections.Generic.List of string()
		
		ReplaceModule(fileName, code) do (context, module):
			ActiveEnvironment.With(context.Environment) do:
				locals.AddRange(LocalAccumulator(fileName, line).FindIn(module))
		return locals
		
		
	[lock]
	virtual def ImportsFor(fileName as string, code as string):
		module = ParseModule(CompileUnit(), fileName, code)
		imports = List of string(i.Namespace for i in module.Imports)
		for ns in _implicitNamespaces:
			imports.Add(ns)
		return imports
		
	[lock]
	virtual def AddReference(assembly as System.Reflection.Assembly):
		_compiler.Parameters.References.Add(assembly)
		
	[lock]
	virtual def AddReference(reference as string):
		_compiler.Parameters.LoadAssembly(reference, false)
		
	private def GetModuleForFileFromContext(context as CompilerContext, fileName as string):
		for m in context.CompileUnit.Modules:
			if m.LexicalInfo.FileName == fileName:
				return m
		return null
		
	private def ParseModule(unit as CompileUnit, fileName as string, contents as string):
		try:
			_parser.Parameters.Input.Add(IO.StringInput(fileName, contents))
			result = _parser.Run(unit)
			DumpErrors result.Errors
			return result.CompileUnit.Modules[-1]
		except x:
			print x
			return Module(LexicalInfo(fileName, 1, 1))
		ensure:
			_parser.Parameters.Input.Clear()
			
	# Recompile a single module and swap it out temporarily to perform an action
	private def ReplaceModule(fileName as string, code as string, action as System.Action[of CompilerContext,Module]):
		if(not _contexts.ContainsKey(fileName)): return
		context = _contexts[fileName]
		originalModule = GetModuleForFileFromContext(context, fileName)
		context.CompileUnit.Modules.Remove(originalModule)
		module = ParseModule(context.CompileUnit, fileName, code)
		context = _compiler.Run(context.CompileUnit)
		action(context,module)
		# DumpErrors (context.Errors)
		context.CompileUnit.Modules.Replace(module, originalModule)
		
				
def DumpErrors(errors as CompilerErrorCollection):
	if SendErrorsToTheConsole:
		for error in errors:
			System.Console.Error.WriteLine(error.ToString(true))

