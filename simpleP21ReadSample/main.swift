//
//  main.swift
//  simpleP21ReadSample
//
//  Created by Yoshida on 2021/10/05.
//  Copyright © 2021 Tsutomu Yoshida, Minokamo, Japan. All rights reserved.
//

import Foundation
import SwiftSDAIcore
import SwiftSDAIap242
import SwiftAP242PDMkit

let na = "n/a"

//MARK: identify the input p21 data file
let testDataFolder = ProcessInfo.processInfo.environment["TEST_DATA_FOLDER"]!

let url = URL(fileURLWithPath: testDataFolder + "NIST_CTC_STEP_PMI/nist_ctc_02_asme1_ap242-e2.stp")
//let url = URL(fileURLWithPath: testDataFolder + "CAx STEP FILE LIBRARY/s1-c5-214/s1-c5-214.stp")

//MARK: create input character stream
let stepsource = try String(contentsOf: url) 
let charstream = stepsource.makeIterator()

//MARK: create output repository
let repository = SDAISessionSchema.SdaiRepository(name: "examle", description: "example repository")

//MARK: prepare a acceptable step schema list
let schemaList: P21Decode.SchemaList = [
	"AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF { 1 0 10303 442 3 1 4 }": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF { 1 0 10303 442 1 1 4 }": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AP203_CONFIGURATION_CONTROLLED_3D_DESIGN_OF_MECHANICAL_PARTS_AND_ASSEMBLIES_MIM_LF  { 1 0 10303 403 3 1 4}": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AP203_CONFIGURATION_CONTROLLED_3D_DESIGN_OF_MECHANICAL_PARTS_AND_ASSEMBLIES_MIM_LF { 1 0 10303 403 2 1 2}": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"CONFIG_CONTROL_DESIGN": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"CONFIGURATION_CONTROL_3D_DESIGN_ED2_MIM_LF { 1 0 10303 403 1 1 4}": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
	"AUTOMOTIVE_DESIGN { 1 0 10303 214 1 1 1 1 }": AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF.self,
]

//MARK: decode p21 char stream
let p21monitor = MyActivityMonitor()

// create a decoder
guard let decoder = P21Decode.Decoder(output: repository, schemaList: schemaList, monitor: p21monitor)
else {
	print("decoder initialization error")
	exit(1)
}

// do decode
guard let createdModels = decoder.decode(input: charstream) else {
 print("decoder error: \(String(describing: decoder.error))")
 exit(2)
}
print("created models: \(createdModels)")

//MARK: create a schema instance containing everything decoded

// obtain a reference to a decoded exchange structure
let exchange = decoder.exchangeStructrure!

// create a schema instance
guard let schema = exchange.shcemaRegistory.values.first else { exit(3) }
let schemaInstance = repository.createSchemaInstance(name: "example", schema: schema.schemaDefinition)

// put all the decoded models into a schema instance
for model in createdModels {
 schemaInstance.add(model:model)
}
schemaInstance.mode = .readOnly
print("")

//MARK: print notable entities
for (i, productDefinition) in productDefinitions(in: schemaInstance).enumerated() {
	// product identification
	let productVersion = version(of: productDefinition)
	let productMaster = masterBase(of: productVersion)
	print("[\(i)] \(productDefinition.complexEntity.leafEntityReferences) id:\(productDefinition.ID.asSwiftType)")
	print("\t\(productVersion.complexEntity.leafEntityReferences) id:\(productVersion.ID.asSwiftType)")
	print("\t\(productMaster.complexEntity.leafEntityReferences) id:\(productMaster.ID.asSwiftType), name:\(productMaster.NAME.asSwiftType)")
	print("")
	
	// product category
	for category in categories(of: productMaster) {
		print("\t\(category.complexEntity.leafEntityReferences) name:\(category.NAME.asSwiftType)")
	}
	
	// product context
	let primaryContex = primaryContext(of: productDefinition)
	print("\t\(primaryContex.complexEntity.leafEntityReferences) name:\(primaryContex.NAME.asSwiftType)")
	print("")
	
	// product properties
	for property in properties(of: productDefinition) {
		print("\t\(property.complexEntity.leafEntityReferences) name:\(property.NAME.asSwiftType)")	
		if let propertyRep = try? representation(of: property) {
			print("\t\t\(propertyRep.complexEntity.leafEntityReferences) name:\(propertyRep.NAME.asSwiftType)")
			
			let contex = context(of: propertyRep)
			print("\t\t\t\(contex.complexEntity.leafEntityReferences) type:\(contex.CONTEXT_TYPE.asSwiftType)")
			
			for repItem in propertyRep.ITEMS {
				print("\t\t\t\(repItem.complexEntity.leafEntityReferences)")
			}
		}		
	}
	print("")
	
	if let productShape = try? shape(of: productDefinition) {
		// shape reps
		for shapeRep in representations(of: productShape) {
			if let definitionalShape = try? definitionalShapeDefinitions(of: shapeRep) {
				print("\t\t\(shapeRep.complexEntity.leafEntityReferences) name:\(shapeRep.NAME.asSwiftType)")
				print("\t\t\tdefinitionalShape:\(definitionalShape.complexEntity.leafEntityReferences)")
			}
		}
		
		// shape aspects
		for aspect in shapeAspects(of: productShape) {
			print("\t\(aspect.complexEntity.leafEntityReferences) name:\(aspect.NAME.asSwiftType)")
			
			for aspectRep in representations(of: aspect) {
				print("\t\t\(aspectRep.complexEntity.leafEntityReferences) name:\(aspectRep.NAME.asSwiftType)")
				
				if let contex = try? context(of: aspectRep) {
					print("\t\t\t\(contex.complexEntity.leafEntityReferences) type:\(contex.CONTEXT_TYPE.asSwiftType)")
				}
				
				for repItem in aspectRep.ITEMS {
					print("\t\t\t\(repItem.complexEntity.leafEntityReferences)")
				}				

				if let definitionalShape = try? definitionalShapeDefinitions(of: aspectRep) {
					print("\t\t\t\(aspectRep.complexEntity.leafEntityReferences) name:\(aspectRep.NAME.asSwiftType)")
					print("\t\t\t\tdefinitionalShape:\(definitionalShape.complexEntity.leafEntityReferences)")
					for docSource in fileLocation(of: definitionalShape) {
						print("\t\t\t\t\tfilename:\(docSource.filename),\tpath:\(docSource.path ?? na),\tmechanism:\(docSource.mechanism ?? na)")
					}
				}
			}
		}
	}
	print("")
	
	// document association
	for docAssociation in associatedDocuments(of: productDefinition) {
		print("\t\(docAssociation.complexEntity.leafEntityReferences) source:\(docAssociation.SOURCE.asSwiftType)")
		
		let doc = docAssociation.ASSIGNED_DOCUMENT
		print("\t\t\(doc.complexEntity.leafEntityReferences) name:\(doc.NAME.asSwiftType)")
		
		let doctype = doc.KIND
		print("\t\t\t\(doctype.complexEntity.leafEntityReferences) type:\(doctype.PRODUCT_DATA_TYPE.asSwiftType)")
		
		if let docfile = documentFile(as: doc) {
			for docSource in fileLocation(of: docfile) {
				print("\t\t\tfilename:\(docSource.filename),\tpath:\(docSource.path ?? na),\tmechanism:\(docSource.mechanism ?? na)")
			}
		}
		else if let managedDoc = try? managedDocument(of: doc) {
			if let docversion = ap242.ePRODUCT_DEFINITION_FORMATION(managedDoc) {
				for docview in documentViews(of: docversion) {
					for docfile in docview.DOCUMENTATION_IDS.compactMap({ documentFile(as: $0) }) {
						for docSource in fileLocation(of: docfile) {
							print("\t\t\tfilename:\(docSource.filename),\tpath:\(docSource.path ?? na),\tmechanism:\(docSource.mechanism ?? na)")
						}
					}
				}
			}
		}
	}
	
	print("")
}

//MARK: - validations
let validationMonitor = MyValidationMonitor()

//MARK: individual where rule validation
var doIndividualWhereValidation = false
if doIndividualWhereValidation {
	let entityType = ap242.eANNOTATION_OCCURRENCE.self	// WHERE_wr1
//	let entityType = ap242.eANNOTATION_PLACEHOLDER_OCCURRENCE.self	// WHERE_wr1
//	let entityType = ap242.eDRAUGHTING_MODEL.self	// WHERE_wr2
//	let entityType = ap242.eFOUNDED_ITEM.self	// WHERE_wr2
//	let entityType = ap242.eMECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION.self	// WHERE_wr8
//	let entityType = ap242.ePLACED_DATUM_TARGET_FEATURE.self	// WHERE_wr3
//	let entityType = ap242.eREPRESENTATION_ITEM.self	// WHERE_wr1
//	let entityType = ap242.eTESSELLATED_ITEM.self	// WHERE_wr1
//	let entityType = ap242.eTESSELLATED_SHAPE_REPRESENTATION.self	// WHERE_wr2


	let instances = schemaInstance.entityExtent(type: entityType)
	for (i,entity) in instances.enumerated() {
		let result = type(of: entity.partialEntity).WHERE_wr1(SELF: entity)
		print("[\(i)] \(entity): \(result)")
		continue
	}
}

//MARK: entity type specific validation
var doEntityValidation = false
if doEntityValidation {
	let entityType = ap242.eANNOTATION_PLACEHOLDER_OCCURRENCE.self
	let instances = schemaInstance.entityExtent(type: entityType)
	for (i,entity) in instances.enumerated() {
		let result = entityType.validateWhereRules(instance: entity, prefix: "\(entity): ")
		print("[\(i)] \(result)")
		continue
	}
}

//MARK: global rule validation
var doGlobalRuleValidation = false
if doGlobalRuleValidation {
	let globalResult = schemaInstance.validateGlobalRules(monitor:validationMonitor)
	print("\n glovalRuleValidationRecord(\(globalResult.count)):\n\(globalResult)"  )
}

//MARK: uniqueness rule validation
var doUniqunessRuleValidation = false
if doUniqunessRuleValidation {
	let uniquenessResult = schemaInstance.validateUniquenessRules(monitor:validationMonitor)
	print("\n uniquenessRuleValidationRecord(\(uniquenessResult.count)):\n\(uniquenessResult)")
}	

//MARK: all where rules validation
var doWhereRuleValidation = false
if doWhereRuleValidation {
	let whereResult = schemaInstance.validateWhereRules(monitor:validationMonitor)
	print("\n whereRuleValidationRecord:\n\(whereResult)" )
}	

//MARK: all validations
var doAllValidaton = false
if doAllValidaton {
	let validationPassed = schemaInstance.validateAllConstraints(monitor: MyValidationMonitor())
	print("validationPassed:", validationPassed)
	print("glovalRuleValidationRecord: \(String(describing: schemaInstance.globalRuleValidationRecord))"  )
	print("uniquenessRuleValidationRecord: \(String(describing: schemaInstance.uniquenessRuleValidationRecord))")
	print("whereRuleValidationRecord: \(String(describing: schemaInstance.whereRuleValidationRecord))" )
}
print("")

//MARK: - entity look up
var name = 1
while name != 0 {
	if let instance = exchange.entityInstanceRegistory[name], let complex = instance.resolved {
		print("#\(name): source = \(instance.source)\n complex = \(complex)\n")
		name = 0
		continue
	}
	else {
		name = 0
		continue
	}
}


print("normal end of execution")
