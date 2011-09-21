namespace Boo.Ide.Tests

import System
import Boo.Lang.Environments

import Boo.Lang.Compiler
import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.Steps

import NUnit.Framework

import Boo.Ide

[TestFixture]
class TargetLookupTest:
	
	[Test]
	def LookupLocalMethod ():
		index = ProjectIndex()
		file = "/foo.boo"
		expectedLine = 9
		expectedColumn = 9
		code = ReIndent("""
class Foo:
	def blah():
		System.Console.WriteLine("foo")
		System.Console.WriteLine("bar")
		System.Console.WriteLine("baz")
		bleh()
		
	def bleh():
		System.Console.WriteLine("bleh")
""")
		location = index.TargetOf (file, code, 7, 4)
		
		Assert.IsNotNull (location)
		Assert.AreEqual (file, location.File)
		Assert.AreEqual (expectedLine, location.Line)
		Assert.AreEqual (expectedColumn, location.Column)
		
	[Test]
	def LookupLocalType ():
		index = ProjectIndex()
		file = "/foo.boo"
		expectedTypeName = "Bar"
		code = ReIndent("""
class Foo:
	def blah():
		bar = null as Bar
		
class Bar:
	static def bleh():
		System.Console.WriteLine("bleh")
""")

		location = index.TargetOf (file, code, 4, 24)
		
		Assert.IsNotNull (location)
		Assert.AreEqual (expectedTypeName, location.TypeName)
