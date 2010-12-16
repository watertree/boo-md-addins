namespace Boo.MonoDevelop.Util

import Boo.Lang.Compiler.Ast

macro ConfigurationItemProperty:
	case [| ConfigurationItemProperty $(ReferenceExpression(Name: name)) = $initialValue |]:
		
		backingField = ReferenceExpression(Name: "_$name")
		yield [|
			private $backingField = $initialValue
		|]
		yield [|
			[ItemProperty($(name.ToLower()))]
			$name:
				get: return $backingField
				set: $backingField = value
		|]
