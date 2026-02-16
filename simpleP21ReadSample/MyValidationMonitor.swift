//
//  MyValidationMonitor.swift
//  swiftP21read
//
//  Created by Yoshida on 2021/07/10.
//  Copyright © 2021 Tsutomu Yoshida, Minokamo, Japan. All rights reserved.
//

import Foundation
import SwiftSDAIcore

//MARK: - validation monitor
class MyValidationMonitor: SDAIPopulationSchema.ValidationMonitor, @unchecked Sendable
{
	var globalCount: Int = 0
	var uniquenessCount: Int = 0
	var complexCount: Int = 0
	var erefCount: Int = 0

	var globalValidated: Int = 0
	var uniquenessValidated: Int = 0
	var complexValidated: Int = 0
	var erefValidated: Int = 0

	var confirmFailedCase = true


  private typealias Stopwatch = ContinuousClock
  private let stopwatch = Stopwatch()


  //MARK: global rules monitor
  private var beginGR: Stopwatch.Instant?
	override func willValidate(
		globalRules: some Collection<SDAIDictionarySchema.GlobalRule> )
	{
		globalCount = globalRules.count
		print("\n validating \(globalCount) global rules:\n ", terminator: "")


    lastTime = stopwatch.now
    lastCompleted = 0
    beginGR = lastTime
	}
  override func completedToValidate(
    globalRules: some Collection<SDAIDictionarySchema.GlobalRule>)
  {
    let duration = beginGR?.duration(to: stopwatch.now)
    print("\n duration: \(duration?.formatted(), default: "n/a")\n")
    beginGR = nil
  }

  //MARK: uniqueness rules monitor
  private var beginUR: Stopwatch.Instant?
	override func willValidate(
		uniquenessRules:some Collection<SDAIDictionarySchema.UniquenessRule>)
	{
		uniquenessCount =  uniquenessRules.count
		print("\n validating \(uniquenessCount) uniqueness rules:\n ", terminator: "")

    lastTime = stopwatch.now
    lastCompleted = 0
    beginUR = lastTime
	}
  override func completedToValidate(
    uniquenessRules:some Collection<SDAIDictionarySchema.UniquenessRule>)
  {
    let duration = beginUR?.duration(to: stopwatch.now)
    print("\n duration: \(duration?.formatted(), default: "n/a")\n")
    beginUR = nil
  }

  //MARK: where rules monitor
  private var beginWR: Stopwatch.Instant?
	override func willValidateWhereRules(
		for complexEntities: some Collection<SDAI.ComplexEntity>)
	{
		complexCount = complexEntities.count
		print("\n validating where rules for \(complexCount) complex entities:\n ", terminator: "")

    lastTime = stopwatch.now
    lastCompleted = 0
    beginWR = lastTime
	}
  override func completedToValidateWhereRules(
    for complexEntities: some Collection<SDAI.ComplexEntity>)
  {
    let duration = beginWR?.duration(to: stopwatch.now)
    print("\n duration: \(duration?.formatted(), default: "n/a")\n")
    beginWR = nil
  }

  //MARK: instance reference domain monitor
  private var beginIRD: Stopwatch.Instant?
	override func willValidateInstanceReferenceDomain(
		for applicationInstances: some Collection<SDAI.EntityReference>)
	{
		erefCount = applicationInstances.count
		print("\n validating instance reference domain for \(erefCount) application instances:\n ", terminator: "")

    lastTime = stopwatch.now
    lastCompleted = 0
    beginIRD = lastTime
	}
  override func completedToValidateInstanceReferenceDomain(
    for applicationInstances: some Collection<SDAI.EntityReference>)
  {
    let duration = beginIRD?.duration(to: stopwatch.now)
    print("\n duration: \(duration?.formatted(), default: "n/a")\n")
    beginIRD = nil
  }


  //MARK: progress marker
  private var lastTime: Stopwatch.Instant?
  private var lastCompleted = 0
  private let completedMark = [
    "a","b","c","d","e","f","g","h","i","j",
    "k","l","m","n","o","p","q","r","s","t",
    "u","v","w","x","y","z",
    "A","B","C","D","E","F","G","H","I","J",
    "K","L","M","N","O","P","Q","R","S","T",
    "U","V","W","X","Y","Z",
  ]
  + Array(repeating: "&", count: 26)
  + Array(repeating: "%", count: 26)
  + Array(repeating: "$", count: 26)
  + Array(repeating: "#", count: 26)
  private var prepend = ""

	private func progressMarker(completed: Int, total: Int) -> String? {
    if total == 0 {
      return nil
    }
    if total <= 100 {
      lastTime = stopwatch.now
      lastCompleted = completed
      let marker = prepend + (completed % 10 == 0 ? "+" : ".")
      prepend = ""
      return marker
    }

		if (completed * 10) % total < 10 {
      lastTime = stopwatch.now
      lastCompleted = completed
      let marker = prepend + "\((completed * 10) / total)"
      prepend = ""
      return marker
		}
		if (completed * 20) % total < 20 {
      lastTime = stopwatch.now
      lastCompleted = completed
      let marker = prepend + "+"
      prepend = ""
      return marker
		}
		if ( completed * 100) % total < 100 {
      lastTime = stopwatch.now
      lastCompleted = completed
      let marker = prepend + "."
      prepend = ""
      return marker
		}

    let nonreported = lastTime?.duration(to: stopwatch.now) ?? .zero
    if nonreported > .seconds(60 * 5) {
      let deltaCompleted = completed - lastCompleted
      let marker = completedMark[min(deltaCompleted, completedMark.count-1)]
      prepend = "\n"
      lastTime = stopwatch.now
      lastCompleted = completed
      return marker
    }

    return nil
	}

  //MARK: validation result progress presenters
	override func didValidateGlobalRule(
		for schemaInstance: SDAIPopulationSchema.SchemaInstance,
		result: SDAIPopulationSchema.GlobalRuleValidationResult)
	{
		globalValidated += 1
    if let marker = progressMarker(completed: globalValidated, total: globalCount) {
      print(marker, terminator: "")
    }

		if result.result == SDAI.FALSE {
      if confirmFailedCase {
        print("\nFAILED: \(result.globalRule.name)")
        let _ = schemaInstance.validate(
          globalRule: result.globalRule, recording: .recordAll)
      }
      else {
        print("/", terminator: "")
      }
		}
	}
	
	override func didValidateUniquenessRule(
		for schemaInstance: SDAIPopulationSchema.SchemaInstance,
		result: SDAIPopulationSchema.UniquenessRuleValidationResult)
	{
		uniquenessValidated += 1
    if let marker = progressMarker(completed: uniquenessValidated, total: uniquenessCount) {
      print(marker, terminator: "")
    }

		if result.result == SDAI.FALSE {
      if confirmFailedCase {
        print("\nFAILED: \(result.uniquenessRule)")
        let _ = schemaInstance.validate(uniquenessRule: result.uniquenessRule)
      }
      else {
        print("/", terminator: "")
      }
		}
	}
  
  override func didValidateWhereRule(
    for complexEntity: SDAI.ComplexEntity,
    result: SDAIPopulationSchema.WhereRuleValidationRecords)
  {
    complexValidated += 1
    if let marker = progressMarker(completed: complexValidated, total: complexCount) {
      print(marker, terminator: "")
    }

    var failed = false
    for (label,whereResult) in result {
      if whereResult == SDAI.FALSE {
        failed = true
        if confirmFailedCase {
          print("\nFAILED: \(label)")
          let _ = complexEntity.validateEntityWhereRules(prefix: "again", recording: .recordFailureOnly)
        }
      }
    }
    if failed && (!confirmFailedCase) {
      print("/", terminator: "")
    }
  }	

	override func didValidateInstanceReferenceDomain(
		for schemaInstance: SDAIPopulationSchema.SchemaInstance,
		applicationInstance: SDAI.EntityReference,
		result: SDAIPopulationSchema.InstanceReferenceDomainValidationResult)
	{
		erefValidated += 1
    if let marker = progressMarker(completed: erefValidated, total: erefCount) {
      print(marker, terminator: "")
    }

		if result.result == SDAI.FALSE {
			print("/", terminator: "")
			if confirmFailedCase {
				let _ = schemaInstance.instanceReferenceDomainNonConformances(entity: applicationInstance, recording: .recordFailureOnly)
			}
		}

	}
}
