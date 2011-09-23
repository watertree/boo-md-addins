namespace Boo.Ide.Tests

import System

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
		location = index.TargetOf (file, code, 7, 10)
		
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
	
	[Test]
	def LookupLocalProperty ():
		index = ProjectIndex()
		file = "/foo.boo"
		expectedLine = 9
		expectedColumn = 5
		code = ReIndent("""
class Foo:
	def blah():
		System.Console.WriteLine("foo")
		System.Console.WriteLine("bar")
		System.Console.WriteLine("baz")
		System.Console.WriteLine(self.bleh)
		
	bleh as int:
		get: return 0
""")
		location = index.TargetOf (file, code, 7, 40)
		
		Assert.IsNotNull (location, "Property lookup failed")
		Assert.AreEqual (file, location.File, "Filename mismatch")
		Assert.AreEqual (expectedLine, location.Line, "Line mismatch")
		Assert.AreEqual (expectedColumn, location.Column, "Column mismatch")
		
	[Test]
	def LookupExternalType ():
		index = ProjectIndex()
		file = "/foo.boo"
		expectedTypeName = "System.Reflection.Assembly"
		code = ReIndent("""
import System.Reflection

class Foo:
	def blah():
		bar = null as Assembly
		
class Bar:
	static def bleh():
		System.Console.WriteLine("bleh")
""")

		location = index.TargetOf (file, code, 6, 20)
		
		Assert.IsNotNull (location)
		Assert.AreEqual (expectedTypeName, location.TypeName)
		
	[Test]
	def LookupExternalMethod ():
		index = ProjectIndex()
		file = "/foo.boo"
		expectedName = "Add"
		expectedTypeFullName = "Boo.Lang.List"
		code = ReIndent("""
class Foo:
	def blah():
		list = List[of string]()
		list.Add("foo")
		list.Add("bar")
		list.Add("baz")
		
class Bar:
	static def bleh():
		System.Console.WriteLine("bleh")
""")

		location = index.TargetOf (file, code, 6, 20)
		
		Assert.IsNotNull (location)
		Assert.IsNotNull (location.MemberInfo)
		Assert.AreEqual (expectedName, location.MemberInfo.Name)
		Assert.IsTrue (location.MemberInfo.DeclaringType.FullName.StartsWith (expectedTypeFullName))
		
	[Test]
	def LookupExternalProperty ():
		index = ProjectIndex()
		file = "/foo.boo"
		expectedName = "Count"
		expectedTypeFullName = "Boo.Lang.List"
		code = ReIndent("""
class Foo:
	def blah():
		list = List[of string]()
		list.Add("foo")
		print(list.Count)
		list.Add("bar")
		
class Bar:
	static def bleh():
		System.Console.WriteLine("bleh")
""")

		location = index.TargetOf (file, code, 6, 20)
		
		Assert.IsNotNull (location, "Property lookup failed")
		Assert.IsNotNull (location.MemberInfo, "External property lookup didn't return external reference")
		Assert.AreEqual (expectedName, location.MemberInfo.Name, "Property name mismatch")
		Assert.IsTrue (location.MemberInfo.DeclaringType.FullName.StartsWith (expectedTypeFullName), "Property declaring type mismatch")
