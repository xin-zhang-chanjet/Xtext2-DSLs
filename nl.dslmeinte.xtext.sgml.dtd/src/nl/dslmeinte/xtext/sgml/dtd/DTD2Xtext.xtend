package nl.dslmeinte.xtext.sgml.dtd

import nl.dslmeinte.xtext.dtd.dtdModel.DocumentTypeDefinition
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.common.util.URI
import nl.dslmeinte.xtext.dtd.dtdModel.*
import org.eclipse.xtext.GrammarUtil
import nl.dslmeinte.xtext.dtd.util.DTDModelUtil
import nl.dslmeinte.xtext.dtd.util.DTDModelUtil2

/**
 * Transforms a {@link DocumentTypeDefinition} into an SGML-style Xtext grammar.
 * 
 * @author Meinte Boersma
 */
class DTD2Xtext {

	def transform(DocumentTypeDefinition dtd, String fqLanguageName, String nsURI) {
		'''
		// generated by DTD2Xtext.xtend
		grammar «fqLanguageName» with nl.dslmeinte.xtext.sgml.base.Base hidden()

		«additionalMetaModelsContent(dtd)»

		generate «dtd.fileNameWithoutExtension().toLowerCase()» «nsURI»

		«sgmlDocumentRuleOverride(dtd)»

		«FOR element : elements(dtd)»
			«transform(element)»
		«ENDFOR»

		«additionalGrammarContent(dtd)»
		'''
	}

	def additionalMetaModelsContent(DocumentTypeDefinition dtd) {
		""	// override in sub classes (no AOP required)
	}

	def additionalGrammarContent(DocumentTypeDefinition dtd) {
		""	// override in sub classes (no AOP required)
	}

	def sgmlDocumentRuleOverride(DocumentTypeDefinition dtd) {
		'''
		// override from Base to include root (of right type):
		SgmlDocument hidden(WHITESPACE, SGML_COMMENTS):
				docType=DocumentType
				root=«elements(dtd).head.name»
			;

		DocumentType hidden(WHITESPACE):
			'<' '!DOCTYPE' rootName=IDENTIFIER ('PUBLIC' | 'SYSTEM') header1=QuotedString header2=QuotedString?
				('[' ( entities+=Entity | SGML_COMMENTS )* ']')? '>'	
			;
		'''
	}

	def elements(DocumentTypeDefinition dtd) {
		dtd.definitions.filter(typeof(Element))
	}

	def fileNameWithoutExtension(EObject eObject) {
		val fileName = eObject.eResource.URI.lastSegment
		val dotIndex = fileName.lastIndexOf('.')
		if( dotIndex < 0 )
			fileName
		else
			fileName.substring(0, dotIndex)
	}

	def transform(Element element) {
		val isCloseTagOptional = element.content instanceof EmptyContent
		val attributes = (new DTDModelUtil2()).attributes(element)
		val attributesCanBeEmpty = attributes.forall( a | true )
		'''
		«element.name» hidden(SGML_COMMENTS«IF !canHaveFollowingContent(element)», WHITESPACE«ENDIF»):
			«element.name»_tagOpen=«element.name»_tagOpen
			«transform(element.content)»
			«IF isCloseTagOptional»(«ENDIF»«element.name»_tagClose=«element.name»_tagClose«IF isCloseTagOptional»)?«ENDIF»
			;

		«element.name»_tagOpen hidden():
			«IF attributesCanBeEmpty»
				{«element.name»_tagOpen}
			«ENDIF»'<' '«element.name»'
			«IF attributes.size > 0»WHITESPACE attributes=«element.name»_attributes«ENDIF» '>';
		«IF attributes.size > 0»«element.name»_attributes hidden(WHITESPACE):
			«IF attributesCanBeEmpty»
				{«element.name»_attributes} 
			«ENDIF»«IF attributes.size > 1»(«ENDIF»«FOR attribute : attributes SEPARATOR ' & '»«transform(attribute)»«ENDFOR»«IF attributes.size > 1»)«ENDIF»;«ENDIF»
		«element.name»_tagClose hidden(): {«element.name»_tagClose} '<' '/' '«element.name»' '>';
		'''
	}

	def canHaveFollowingContent(Element element) {
		element.content.canHaveFollowingContent()
	}

	def dispatch canHaveFollowingContent(Expression expression) {
		System::err.println( '''no canHaveFollowingContent def for sub type «expression.eClass.name» of «DtdModelPackage::eINSTANCE.expression.name»''' )
		false
	}

	def dispatch canHaveFollowingContent(Alternatives alternatives) {
		alternatives.alternatives.exists( e | canHaveFollowingContent(e) )
	}

	// (needs to be explicitly defined as returning a Boolean: because of recursion without further coercion?)
	def dispatch Boolean canHaveFollowingContent(Concatenation concatenation) {
		canHaveFollowingContent(concatenation.members.head)
	}

	// (needs to be explicitly defined as returning a Boolean: because of recursion without further coercion?)
	def dispatch Boolean canHaveFollowingContent(Cardinality cardinality) {
		canHaveFollowingContent(cardinality.nestedExpr)
	}

	def dispatch canHaveFollowingContent(EmptyContent emptyContent) {
		false
	}

	def dispatch canHaveFollowingContent(PCData pcData) {
		true
	}

	def dispatch canHaveFollowingContent(ElementReference elementReference) {
		false
	}

	def transform(Attribute attribute) {
		val isOptional = ( attribute.cardinality == AttributeCardinality::IMPLIED )
		'''
		«IF isOptional»(«ENDIF»'«attribute.name»' '=' «attribute.name»=QuotedString«IF isOptional»)?«ENDIF»
		'''
	}

	def dispatch transform(Expression expression) {
		System::err.println( '''no transform def for sub type «expression.eClass.name» of «DtdModelPackage::eINSTANCE.expression.name»''' )
		""
	}

	def dispatch transform(Alternatives alternatives) {
		'''
		( «FOR expression : alternatives.alternatives SEPARATOR ' | '»«transform(expression)»«ENDFOR» )
		'''
	}

	def dispatch transform(Concatenation concatenation) {
		'''
		«FOR expression : concatenation.members SEPARATOR ' '»«transform(expression)»«ENDFOR»
		'''
	}

	def dispatch transform(Cardinality cardinality) {
		'''
		(«transform(cardinality.nestedExpr)»)«syntax(cardinality.cardinality)»
		'''
	}

	def dispatch transform(EmptyContent emptyContent) {
		""
	}

	def dispatch transform(PCData pcData) {
		'''contents+=_PCDATA'''
	}

	def dispatch transform(ElementReference elementReference) {
		'''contents+=«elementReference.element.name»'''
	}

	def syntax(ElementCardinality cardinality) {
		switch(cardinality) {
			case ElementCardinality::OPTIONAL		: '?'
			case ElementCardinality::ZERO_OR_MORE	: '*'
			case ElementCardinality::ONE_OR_MORE	: '+'
			case null								: ''
			default	: 'error'
		}
	}

}