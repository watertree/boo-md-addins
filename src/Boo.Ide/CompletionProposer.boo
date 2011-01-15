namespace Boo.Ide

import Boo.Lang.Compiler.Ast

import Boo.Lang.Compiler.TypeSystem
import Boo.Lang.Compiler.TypeSystem.Core

import Boo.Lang.Environments
import Boo.Lang.PatternMatching

import System.Linq.Enumerable

class CompletionProposal:
	[getter(Entity)] _entity as IEntity
	[getter(Name)] _name as string
	[getter(EntityType)] _entityType as EntityType
	[getter(Description)] _description as string
	
	def constructor(entity as IEntity):
		_entity = entity
		_name = entity.Name
		_entityType = entity.EntityType
		ambiguous = entity as Ambiguous
		if ambiguous is not null:
			_description = "${ambiguous.Entities[0]} (${ambiguous.Entities.Length} overloads)"
		else:
			_description = entity.ToString()

static class CompletionProposer:
	
	def ForExpression(expression as Expression):
		match expression:
			case MemberReferenceExpression(Target: target=Expression(ExpressionType)):
				match target.Entity:
					case IType():
						members = StaticMembersOf(ExpressionType)
					case ns=INamespace(EntityType: EntityType.Namespace):
						members = ns.GetMembers()
					otherwise:
						members = InstanceMembersOf(ExpressionType)
				
				membersByName = members.GroupBy({ member | member.Name })
				for member in membersByName:
					yield CompletionProposal(Entities.EntityFromList(member.ToList()))
			otherwise:
				pass
				
	def InstanceMembersOf(type as IType):
		for member in AccessibleMembersOf(type):
			match member:
				case IAccessibleMember(IsStatic):
					yield member unless IsStatic
				otherwise:
					yield member
					
	def StaticMembersOf(type as IType):
		for member in AccessibleMembersOf(type):
			match member:
				case IAccessibleMember(IsStatic):
					yield member if IsStatic
				otherwise:
					yield member
				
	def AccessibleMembersOf(type as IType):
		currentType = type
		while currentType is not null:
			for member in currentType.GetMembers():
				if IsSpecialName(member.Name):
					continue
				match member:
					case IConstructor():
						continue
					case IEvent():
						yield member
					case IAccessibleMember(IsPublic):
						if IsPublic:
							yield member
					otherwise:
						continue
			if currentType.IsInterface:
				currentType = (currentType.GetInterfaces() as IType*).FirstOrDefault() or my(TypeSystemServices).ObjectType
			else:
				currentType = currentType.BaseType
			
	_specialPrefixes = { "get_": 1, "set_": 1, "add_": 1, "remove_": 1, "op_": 1 }
	
	def IsSpecialName(name as string):
		index = name.IndexOf('_')
		return false if index < 0
		
		prefix = name[:index + 1]
		return prefix in _specialPrefixes

