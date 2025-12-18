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

let stopwatch = ContinuousClock()
let beginRun = stopwatch.now
print(Date.now.formatted())

//MARK: identify the input p21 data file
let testDataFolder = ProcessInfo.processInfo.environment["TEST_DATA_FOLDER"]!


///https://www.nist.gov/ctl/smart-connected-systems-division/smart-connected-manufacturing-systems-group/mbe-pmi-0
let url = URL(fileURLWithPath: testDataFolder + "NIST-PMI-STEP-Files/" +
              "nist_ctc_01_asme1_ap242-e1.stp"
//              "nist_ctc_02_asme1_ap242-e2.stp"
//              "nist_ctc_03_asme1_ap242-e2.stp"
//              "nist_ctc_04_asme1_ap242-e1.stp"
//              "nist_ctc_05_asme1_ap242-e1.stp"
//              "nist_ftc_06_asme1_ap242-e2.stp"
//              "nist_ftc_07_asme1_ap242-e2.stp"
//              "nist_ftc_08_asme1_ap242-e1-tg.stp"
//              "nist_ftc_08_asme1_ap242-e2.stp"
//              "nist_ftc_09_asme1_ap242-e1.stp"
//              "nist_ftc_10_asme1_ap242-e2.stp"
//              "nist_ftc_11_asme1_ap242-e2.stp"
//              "nist_stc_06_asme1_ap242-e3.stp"
//              "nist_stc_07_asme1_ap242-e3.stp"
//              "nist_stc_08_asme1_ap242-e3.stp"
//              "nist_stc_09_asme1_ap242-e3.stp"
//              "nist_stc_10_asme1_ap242-e2.stp"
)

///https://www.cax-if.org/cax/cax_stepLib.php
///(not accessible any more.)
//let url = URL(fileURLWithPath: testDataFolder + "CAx STEP FILE LIBRARY/" +
//              "s1-c5-214/MAINBODY_BACK.stp"
//)

print("\n input: \(url.lastPathComponent)\n\n")

//MARK: create input character stream
let stepsource = try String(contentsOf: url, encoding: .utf8)
let charstream = stepsource.makeIterator()

//MARK: create output repository
let repository = SDAISessionSchema.SdaiRepository(name: "example", description: "example repository")

let schemaInstanceName = "example"

//MARK: create SDAI-session
let session = SDAI.openSession(knownServers: [repository])
let _ = session.startEventRecording()
session.open(repository: repository)

//MARK: start RW transaction
let exchange = await session.performTransactionRW(output: P21Decode.ExchangeStructure.self) { transaction in

	//MARK: prepare the acceptable step schema list
	let schemaList: P21Decode.SchemaList = [
    "AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF { 1 0 10303 442 4 1 4 }": ap242.self,
		"AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF { 1 0 10303 442 3 1 4 }": ap242.self,
		"AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF { 1 0 10303 442 1 1 4 }": ap242.self,
		"AP203_CONFIGURATION_CONTROLLED_3D_DESIGN_OF_MECHANICAL_PARTS_AND_ASSEMBLIES_MIM_LF  { 1 0 10303 403 3 1 4}": ap242.self,
		"AP203_CONFIGURATION_CONTROLLED_3D_DESIGN_OF_MECHANICAL_PARTS_AND_ASSEMBLIES_MIM_LF { 1 0 10303 403 2 1 2}": ap242.self,
		"CONFIG_CONTROL_DESIGN": ap242.self,
		"CONFIGURATION_CONTROL_3D_DESIGN_ED2_MIM_LF { 1 0 10303 403 1 1 4}": ap242.self,
		"AUTOMOTIVE_DESIGN { 1 0 10303 214 1 1 1 1 }": ap242.self,
	]

	//MARK: decode p21 char stream
	let p21monitor = MyActivityMonitor()
	
	// create a decoder
	guard let decoder = P21Decode.Decoder(output: repository, schemaList: schemaList, monitor: p21monitor)
	else {
		SDAI.raiseErrorAndTrap(.SY_ERR, detail: "decoder initialization error")
	}

	// do decode
	guard let createdModels = decoder.decode(
		input: charstream,
		transaction: transaction)
	else {
    SDAI.raiseErrorAndTrap(.SY_ERR, detail: "decoder error: \(decoder.error, default: "nil")")
	}
  // obtain a reference to a decoded exchange structure
  let exchange = decoder.exchangeStructure!

  print("\n source p21 file: \(exchange.headerSection.fileName)")
  print("\n created models: \(createdModels.map{$0.name})")

  //MARK: create a schema instance containing everything decoded

	// create a schema instance
	guard let schema = createdModels.first?.underlyingSchema,
				let schemaInstance = transaction.createSchemaInstance(
					repository: repository, name: schemaInstanceName, schema: schema)
	else {
		SDAI.raiseErrorAndTrap(.SY_ERR, detail: "could not create schema instance")
	}

	// put all the decoded models into a schema instance
	for model in createdModels {
    let _ = await transaction.addSdaiModel(instance: schemaInstance, model: model)
	}

	return .commit(exchange)
}

print("\n(1) decode complete\n\n")

await session.performTransactionRO { transaction in
	guard let schemaInstance = repository.contents.findSchemaInstance(named: schemaInstanceName)
	else {
		SDAI.raiseErrorAndContinue(.SY_ERR, detail: "could not find schema instance[\(schemaInstanceName)] in repository[\(repository)]")
		return SDAISessionSchema.SdaiTransaction.Disposition<Void>.abort
	}

	//MARK: print notable entities
  let APPLICATION_CONTEXT = schemaInstance.entityExtent(type: ap242.eAPPLICATION_CONTEXT.self)

  for (i,AC) in APPLICATION_CONTEXT.enumerated() {
    print("APPLICATION_CONTEXT[\(i)] #\(AC.complexEntity.p21name): APPLICATION(\(AC.APPLICATION)), ID(\(AC.ID, default: "nil")), DESCRIPTION(\(AC.DESCRIPTION, default: "nil")) \n")

    let APDs = SDAI.USEDIN(T: AC, ROLE: \ap242.eAPPLICATION_PROTOCOL_DEFINITION.APPLICATION)
    for APD in APDs {
      print( "APPLICATION_PROTOCOL_DEFINITION #\(APD.complexEntity?.p21name, default: "nil"): \(APD.APPLICATION_INTERPRETED_MODEL_SCHEMA_NAME, default: "nil")\n" )
    }
    print("\n")
  }


	for (i, productDefinition) in productDefinitions(in: schemaInstance).enumerated() {

		// product identification
		let productVersion = version(of: productDefinition)
		let productMaster = masterBase(of: productVersion)
		print("product identification[\(i)] \(productDefinition.complexEntity?.leafEntityReferences, default: "nil") id:'\(productDefinition.ID?.asSwiftType ?? "nil")'")
		print("\t\(productVersion.complexEntity?.leafEntityReferences, default: "nil") id:'\(productVersion.ID?.asSwiftType ?? "nil")'")
		print("\t\(productMaster.complexEntity?.leafEntityReferences, default: "nil") id:'\(productMaster.ID?.asSwiftType ?? "nil")', name:'\(productMaster.NAME?.asSwiftType ?? "nil")'")
		print("")

		// product category
		for category in categories(of: productMaster) {
			print("\tproduct category:\(category.complexEntity?.leafEntityReferences, default: "nil") name:'\(category.NAME?.asSwiftType ?? "nil")'")
		}

		// product context
		let primaryContex = primaryContext(of: productDefinition)
		print("\tproduct context:\(primaryContex.complexEntity?.leafEntityReferences, default: "nil") name:'\(primaryContex.NAME?.asSwiftType ?? "nil")'")
		print("")

		// assembly structure
		let parents = parentAssemblies(of: productDefinition)
		if parents.isEmpty {
			print("\t*** TOP LEVEL ASSEMBLY ***\n")
		}
		else {
			for (j, parent) in parents.enumerated() {
				print("\tparent[\(i).\(j)]\(parent.complexEntity?.leafEntityReferences, default: "nil"), product_def:\(parent.RELATING_PRODUCT_DEFINITION, default: "nil")")

				if let contextDependentShapeRep = try? assemblyComponentTransformationRelationship(of: parent) {
					let repRelation = contextDependentShapeRep.REPRESENTATION_RELATION
					print("\t\tcontext dep. shape rep:\(contextDependentShapeRep.complexEntity?.leafEntityReferences, default: "nil")")
					print("\t\trep. relation:\(repRelation?.complexEntity?.leafEntityReferences, default: "nil")")

					if let repRelationWithTransformation = repRelation?.super_eREPRESENTATION_RELATIONSHIP?.sub_eREPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION {
						let transOp = repRelationWithTransformation.TRANSFORMATION_OPERATOR
						print("\t\ttransformation:\(transOp)")
						let itemDefTrans = transOp.super_eITEM_DEFINED_TRANSFORMATION
						print("\t\tsource:\(itemDefTrans.TRANSFORM_ITEM_1?.complexEntity?.leafEntityReferences, default: "nil")")
						print("\t\ttarget:\(itemDefTrans.TRANSFORM_ITEM_2?.complexEntity?.leafEntityReferences, default: "nil")")
					}
					print("")
				}

				if let asAssembledShape = try? asAssembledShape(of: parent) {
					print("\t\tas assembled shape:\(asAssembledShape.complexEntity?.leafEntityReferences, default: "nil")")
					print("")
				}

				if let mappedItem = try? explicitShape(of: parent) {
					let mappingTarget = mappedItem.MAPPING_TARGET
					let mappingSource = mappedItem.MAPPING_SOURCE
					let mappedRep = mappingSource?.MAPPED_REPRESENTATION
					let mappingOrigin = mappingSource?.MAPPING_ORIGIN
					print("\t\tmapped item:\(mappedItem.complexEntity?.leafEntityReferences, default: "nil")")
					print("\t\tmapping target:\(mappingTarget?.complexEntity?.leafEntityReferences, default: "nil")")
					print("\t\tmapping source:\(mappingSource?.complexEntity?.leafEntityReferences, default: "nil")")
					print("\t\tmapped rep:\(mappedRep?.complexEntity?.leafEntityReferences, default: "nil")")
					print("\t\tmapping origin:\(mappingOrigin?.complexEntity?.leafEntityReferences, default: "nil")")
					print("")
				}
			}
		}
		
		
		
		// product properties
		for (j, property) in properties(of: productDefinition).enumerated() {
			print("\tproduct property[\(i).\(j)]\(property.complexEntity?.leafEntityReferences, default: "nil") name:'\(property.NAME?.asSwiftType, default: "nil")'")
			if let propertyRep = try? representation(of: property) {
				print("\t\t\(propertyRep.complexEntity?.leafEntityReferences, default: "nil") name:'\(propertyRep.NAME?.asSwiftType, default: "nil")'")

				let contex = context(of: propertyRep)
				print("\t\t\t\(contex.complexEntity?.leafEntityReferences, default: "nil") type:'\(contex.CONTEXT_TYPE?.asSwiftType, default: "nil")'")
				if let globalUnitAssigned = ap242.eGLOBAL_UNIT_ASSIGNED_CONTEXT(contex.complexEntity) {
					for (k,unit) in globalUnitAssigned.UNITS.enumerated() {
						printUnit(indent: "\(k).\t\t\t\t", unit: unit)
					}
				}
				print("")

				if let items = propertyRep.ITEMS {
					for (k, repItem) in items.enumerated() {
						print("\t\t\trep[\(i).\(j).\(k)]\(repItem.complexEntity?.leafEntityReferences, default: "nil")")
					}
				}
			}		
		}
		print("")
		
		if let productShape = try? shape(of: productDefinition) {
			print("\tproduct shape:\(productShape)")
			// shape reps
			for (j, shapeDefRep) in representations(of: productShape).enumerated() {
				let shapeRep = shapeDefRep.USED_REPRESENTATION
				print("\t\tshape rep[\(i).\(j)]\(shapeRep?.complexEntity?.leafEntityReferences, default: "nil") name:'\(shapeRep?.NAME?.asSwiftType, default: "nil")'")
				if let definitionalShape = try? definitionalShapeDefinitions(of: shapeRep) {
					print("\t\t\tdefinitionalShape:\(definitionalShape.complexEntity?.leafEntityReferences, default: "nil")")
				}
			}
			
			// shape aspects
			for (j, aspect) in shapeAspects(of: productShape).enumerated() {
				print("\tshape aspect[\(i).\(j)]\(aspect.complexEntity?.leafEntityReferences, default: "nil") name:'\(aspect.NAME?.asSwiftType, default: "nil")'")

				for (k,shapeDefRep) in representations(of: aspect).enumerated() {
					guard let aspectRep = shapeDefRep.USED_REPRESENTATION?.eval else { continue }
					print("\t\t[\(i).\(j).\(k)]\(aspectRep.complexEntity.leafEntityReferences) name:'\(aspectRep.NAME.asSwiftType)'")
					
					if let contex = try? context(of: aspectRep.pRef).eval {
						print("\t\t\t\(contex.complexEntity.leafEntityReferences) type:'\(contex.CONTEXT_TYPE.asSwiftType)'")
					}
					
					for repItem in aspectRep.ITEMS.compactMap({$0.eval}) {
						print("\t\t\t\(repItem.complexEntity.leafEntityReferences)")
					}				
					
					if let definitionalShape = try? definitionalShapeDefinitions(of: aspectRep.pRef)?.eval {
						print("\t\t\t\(aspectRep.complexEntity.leafEntityReferences) name:'\(aspectRep.NAME.asSwiftType)'")
						print("\t\t\t\tdefinitionalShape:\(definitionalShape.complexEntity.leafEntityReferences)")
						for docSource in fileLocations(of: definitionalShape.pRef) {
							print("\t\t\t\t\tfilename:\(docSource.fileName),\tpath:\(docSource.path ?? na),\tmechanism:\(docSource.mechanism ?? na)")
						}
					}
				}
			}
		}
		print("")
		
		// document association
		for (j,docAssociation) in associatedDocuments(of: productDefinition).compactMap({$0.eval}).enumerated() {
			print("\tdocument association[\(i).\(j)]\(docAssociation.complexEntity.leafEntityReferences) source:'\(docAssociation.SOURCE.asSwiftType)'")
			
			let doc = docAssociation.ASSIGNED_DOCUMENT
			print("\t\t\(doc.complexEntity?.leafEntityReferences, default: "nil") name:'\(doc.NAME?.asSwiftType, default: "nil")'")

			let doctype = doc.KIND
			print("\t\t\t\(doctype?.complexEntity?.leafEntityReferences, default: "nil") type:'\(doctype?.PRODUCT_DATA_TYPE?.asSwiftType, default: "nil")'")

			if let docfile = documentFile(as: doc) {
				for docSource in fileLocations(of: docfile) {
					print("\t\t\tfilename:\(docSource.fileName),\tpath:\(docSource.path ?? na),\tmechanism:\(docSource.mechanism ?? na)")
				}
			}
			else if let managedDoc = try? managedDocument(of: doc) {
				if let docversion = ap242.ePRODUCT_DEFINITION_FORMATION(managedDoc) {
					for docview in documentViews(of: docversion.pRef).compactMap({ $0.eval }) {
						for docfile in docview.DOCUMENTATION_IDS.compactMap({ documentFile(as: $0) }) {
							for docSource in fileLocations(of: docfile) {
								print("\t\t\tfilename:\(docSource.fileName),\tpath:\(docSource.path ?? na),\tmechanism:\(docSource.mechanism ?? na)")
							}
						}
					}
				}
			}
		}
		
		print("")
	}


	return .commit(Void())
}

print("\n(2) inspection complete\n\n")

//MARK: - validations

await session.performTransactionVA { transaction in
	guard
	let si = repository.contents.findSchemaInstance(named: schemaInstanceName),
	let schemaInstance = transaction.promoteSchemaInstanceToReadWrite(instance: si)
	else {
		SDAI.raiseErrorAndContinue(.SY_ERR, detail: "could not obtain schema instance[\(schemaInstanceName)] in RW mode")
		return .abort
	}

	let validationMonitor = MyValidationMonitor()

  //MARK: individual unique rule validation
  let doIndividualUniqueValidation = false
  if doIndividualUniqueValidation {

//    let entityType = ap242.eDATUM_SYSTEM.self // UNIQUE_ur1
    let entityType = ap242.eITEM_IDENTIFIED_REPRESENTATION_USAGE.self // UNIQUE_ur1, UNIQUE_ur2

    let instances = schemaInstance.entityExtent(type: entityType)
    var uniqueCombinations = [AnyHashable:SDAI.EntityReference]()

    for (i,entity) in instances.enumerated() {
      guard let result = type(of: entity.partialEntity).UNIQUE_ur2(SELF: entity) else { continue }

      if let registered = uniqueCombinations[result] {
        print("[\(i)] \(entity): has non-unique value as \(registered)")
      }
      else {
        uniqueCombinations[result] = entity
      }
      continue
    }
  }

	//MARK: individual where rule validation
	let doIndividualWhereValidation = false
	if doIndividualWhereValidation {
//    let entityType = ap242.eADVANCED_FACE.self  // WHERE_wr4
//    let entityType = ap242.eANNOTATION_OCCURRENCE.self  // WHERE_wr1
//    let entityType = ap242.eANNOTATION_PLACEHOLDER_OCCURRENCE.self  // WHERE_wr1,_wr2
//    let entityType = ap242.eANNOTATION_PLANE.self  // WHERE_wr3
//    let entityType = ap242.eCAMERA_MODEL.self  // WHERE_wr1
//    let entityType = ap242.eDATUM.self  // WHERE_wr1
//    let entityType = ap242.eDATUM_FEATURE.self  // WHERE_wr1
    let entityType = ap242.eDEFAULT_MODEL_GEOMETRIC_VIEW.self  // WHERE_wr1,_wr2,_wr3
//    let entityType = ap242.eGEOMETRICALLY_BOUNDED_WIREFRAME_SHAPE_REPRESENTATION.self  // WHERE_wr3
//    let entityType = ap242.eREPRESENTATION_ITEM.self  // WHERE_wr1
//		let entityType = ap242.eTESSELLATED_ITEM.self	// WHERE_wr1

		
		let instances = schemaInstance.entityExtent(type: entityType)
		for (i,entity) in instances.enumerated() {
			let result = type(of: entity.partialEntity).WHERE_wr1(SELF: entity.pRef)
      if result == SDAI.FALSE {
        print("[\(i)] \(entity) #\(entity.complexEntity.p21name): \(result)")
      }
		}
	}
  /*
   */

	//MARK: entity type specific validation
	let doEntityValidation = false
  if doEntityValidation {
    let entityTypes = [
      ap242.eANNOTATION_OCCURRENCE.self,
      ap242.eANNOTATION_PLACEHOLDER_OCCURRENCE.self,
      ap242.eANNOTATION_PLANE.self,
      ap242.eCAMERA_MODEL.self,
      ap242.eDATUM.self,
      ap242.eDATUM_FEATURE.self,
      ap242.eDEFAULT_MODEL_GEOMETRIC_VIEW.self,
      ap242.eGEOMETRICALLY_BOUNDED_WIREFRAME_SHAPE_REPRESENTATION.self,
      ap242.eREPRESENTATION_ITEM.self,
      ap242.eTESSELLATED_ITEM.self,
    ]

    for entityType in entityTypes {
      let instances = schemaInstance.entityExtent(type: entityType)
      for (i,entity) in instances.enumerated() {
        let result = entityType.validateWhereRules(instance: entity, prefix: "\(entity): ")
        let failedResult = result.filter { $0.value == SDAI.FALSE }
        if failedResult.isEmpty { continue }
        
        print("[\(i)] entity:#\(entity.complexEntity.p21name)\n\(failedResult)")
        let again = entityType.validateWhereRules(instance: entity, prefix: "\(entity): ")
      }
    }
  }

  //MARK: individual global rule validation
  let doIndividualGlobalRuleValidation = false
  if doIndividualGlobalRuleValidation {

    if let rule = schemaInstance.nativeSchema
      .globalRules["AP242_APPLICATION_PROTOCOL_DEFINITION_REQUIRED"]
    {
      let result = schemaInstance.validate(
        globalRule: rule,
        recording: .recordAll)
      print(result)
    }
  }

	//MARK: instance referene domain validation
	let doInstanceReferenceDomainValidation = false
	if doInstanceReferenceDomainValidation {
		let domainResult = schemaInstance.validateAllInstanceReferenceDomain(
			recording: .recordFailureOnly, monitor: validationMonitor)
		print("\n instanceReferenceDomainValidationRecord(\(domainResult.record.count)):\n\(domainResult.record)" )
	}

	//MARK: global rule validation
	let doGlobalRuleValidation = false
	if doGlobalRuleValidation {
		let globalResult = schemaInstance.validateAllGlobalRules(
			recording: .recordFailureOnly, monitor:validationMonitor)
		print("\n globalRuleValidationRecord(\(globalResult.count)):\n\(globalResult)"  )
  }

	//MARK: uniqueness rule validation
	let doUniqunessRuleValidation = false
	if doUniqunessRuleValidation {
		let uniquenessResult = schemaInstance.validateAllUniquenessRules(
			recording: .recordFailureOnly, monitor:validationMonitor)
		print("\n uniquenessRuleValidationRecord(\(uniquenessResult.count)):\n\(uniquenessResult)")
	}

	//MARK: all where rules validation
	let doWhereRuleValidation = false
	if doWhereRuleValidation {
		let whereResult = schemaInstance.validateAllWhereRules(
			recording: .recordFailureOnly, monitor:validationMonitor)
		print("\n whereRuleValidationRecord:\n\(whereResult)" )
	}

	//MARK: all validations
	let doAllValidation = true
	if doAllValidation {
    let validationPassed = await transaction.validateSchemaInstanceAsync(
			instance: schemaInstance,
      option: .recordFailureOnly,
      monitor: validationMonitor)

		print("\n SCHEMA INSTANCE VALIDATION RESULT\n validationPassed?: \(validationPassed)")

		print("\n instanceReferenceDomainValidationRecord: \(schemaInstance.instanceReferenceDomainValidationRecord, default: "nil")")

		print("\n globalRuleValidationRecord: \(schemaInstance.globalRuleValidationRecordDescription)"  )

		print("\n uniquenessRuleValidationRecord: \( schemaInstance.uniquenessRuleValidationRecordDescription)")

		print("\n whereRuleValidationRecord: \( schemaInstance.whereRuleValidationRecord, default: "nil")" )
	}

	return .commit
}
print("\n(3) validation complete\n\n")


await session.performTransactionRO { transaction in
	guard case .commit(let exchange) = exchange else { return .abort }

	//MARK: - entity look up
	var name = 29
	while name != 0 {
		if let instance = exchange.entityInstanceRegistry[name],
			 let complex = instance.resolved
		{
			print("#\(name): source = \(instance.source)\n complex = \(complex)\n")
			if let entity = complex.entityReference(ap242.eFOUNDED_ITEM.self),
				 let users = entity.USERS
			{
				print("users.count = \(users.size, default: "nil")")
				for (i,user) in users.enumerated() {
					print("[\(i)] user = #\(user.entityReferences.map{$0.complexEntity.p21name})")
				}
			}


			name = 0
			continue
		}
		else {
			name = 0
			continue
		}
	}


	return .commit
}


print("normal end of execution")
let durationRun = beginRun.duration(to: stopwatch.now)
print(Date.now.formatted())
print("total duration: \(durationRun.formatted())")


//MARK: -
func printUnit(indent:String, unit:ap242.sUNIT) {
  if let namedUnit = unit.super_eNAMED_UNIT.eval {
    print(indent+"unit:\(namedUnit.complexEntity.leafEntityReferences)")

    if let siUnit = namedUnit.sub_eSI_UNIT {
      print(indent+"\t\(String(describing: siUnit.PREFIX)) \(siUnit.NAME)")
    }
    else if let convUnit = namedUnit.sub_eCONVERSION_BASED_UNIT {
      print(indent+"\t\(convUnit.NAME.asSwiftString) factor:\(String(describing: convUnit.CONVERSION_FACTOR.VALUE_COMPONENT)) times ...")
      if let baseUnit = convUnit.CONVERSION_FACTOR.UNIT_COMPONENT {
        printUnit(indent: indent+"\t\t", unit: baseUnit)
      }
    }
  }

  else if let derivedUnit = unit.super_eDERIVED_UNIT.eval {
    print(indent+"unit:\(derivedUnit.NAME?.asSwiftString ?? "<no name>" )\t\(derivedUnit.complexEntity.leafEntityReferences)")

    for (m,elem) in derivedUnit.ELEMENTS.enumerated() {
      print(indent+"\t[\(m)] exponent:\(String(describing: elem.EXPONENT?.asSwiftType))\t\(String(describing: elem.UNIT?.complexEntity?.leafEntityReferences))")
      if let siUnit = elem.UNIT?.sub_eSI_UNIT {
        print(indent+"\t\t(String(describing: siUnit.PREFIX)) \(siUnit.NAME)")
      }
    }
  }
}
