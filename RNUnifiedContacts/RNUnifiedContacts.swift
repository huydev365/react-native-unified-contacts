//
//  RNUnifiedContacts.swift
//  RNUnifiedContacts
//
//  Copyright © 2016 Joshua Pinter. All rights reserved.
//

import Contacts
import ContactsUI
import Foundation

@available(iOS 9.0, *)
@objc(RNUnifiedContacts)
extension NSObject {
    @objc
    func value(forUndefinedKey key: String) -> Any {
        return ""
    }
}
class RNUnifiedContacts: NSObject {

    //  iOS Reference: https://developer.apple.com/library/ios/documentation/Contacts/Reference/CNContact_Class/#//apple_ref/doc/constant_group/Metadata_Keys

    let keysToFetch = [
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactDatesKey as CNKeyDescriptor,
        CNContactDepartmentNameKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
//        CNContactImageDataKey,
        CNContactInstantMessageAddressesKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactNamePrefixKey as CNKeyDescriptor,
        CNContactNameSuffixKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactNonGregorianBirthdayKey as CNKeyDescriptor,
        // CNContactNoteKey, // NOTE: iOS 13 does not allow fetching of notes without the com.apple.developer.contacts.notes entitlement, which requires special permission from Apple.
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactPhoneticFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneticGivenNameKey as CNKeyDescriptor,
        CNContactPhoneticMiddleNameKey as CNKeyDescriptor,
        // CNContactPhoneticOrganizationNameKey,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactPreviousFamilyNameKey as CNKeyDescriptor,
        CNContactRelationsKey as CNKeyDescriptor,
        CNContactSocialProfilesKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactTypeKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]


    @objc func userCanAccessContacts(_ callback: (Array<Bool>) -> ()) -> Void {
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)

        switch authorizationStatus{
        case .notDetermined, .restricted, .denied:
            callback([false])

        case .authorized:
            callback([true])
        }
    }

    @objc func requestAccessToContacts(_ callback: @escaping (Array<Bool>) -> ()) -> Void {
        userCanAccessContacts() { (userCanAccessContacts) in
            if (userCanAccessContacts == [true]) {
                callback([true])
                return
            }

            CNContactStore().requestAccess(for: CNEntityType.contacts) { (userCanAccessContacts, error) in
                if (userCanAccessContacts) {
                    callback([true])
                    return
                } else {
                    callback([false])
                    return
                }
            }
        }
    }

    @objc func alreadyRequestedAccessToContacts(_ callback: (Array<Bool>) -> ()) -> Void {
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)

        switch authorizationStatus{
        case .notDetermined:
            callback([false])

        case .authorized, .restricted, .denied:
            callback([true])
        }
    }

    @objc func getContact(_ identifier: String, callback: (NSArray) -> () ) -> Void {
        let cNContact = getCNContact( identifier, keysToFetch: keysToFetch as [CNKeyDescriptor] )
        if ( cNContact == nil ) {
            callback( ["Could not find a contact with the identifier ".appending(identifier), NSNull()] )
            return
        }

        let contactAsDictionary = convertCNContactToDictionary( cNContact! )
        callback( [NSNull(), contactAsDictionary] )
    }

    @objc func getGroup(_ identifier: String, callback: (NSArray) -> () ) -> Void {
        let cNGroup = getCNGroup( identifier )
        if ( cNGroup == nil ) {
          callback( ["Could not find a group with the identifier ".appending(identifier), NSNull()] )
          return
        }

        let groupAsDictionary = convertCNGroupToDictionary( cNGroup! )
        callback( [NSNull(), groupAsDictionary] )
    }

    // Pseudo overloads getContacts but with no searchText.
    // Makes it easy to get all the Contacts with not passing anything.
    // NOTE: I tried calling the two methods the same but it barfed. It should be
    //   allowed but perhaps how React Native is handling it, it won't work. PR
    //   possibility.
    //
    @objc func getContacts(_ callback: (NSObject) -> ()) -> Void {
        searchContacts(nil) { (result: NSObject) in
            callback(result)
        }
    }
  
    @objc func getContainers(_ callback: (NSArray) -> ()) -> Void {
        let contactStore = CNContactStore()
        do {
            var cnContainers = [CNContainer]()
            try cnContainers = contactStore.containers(matching: nil)
            var containers = [NSDictionary]();
            for cnContainer in cnContainers {
                containers.append( convertCNContainerToDictionary(cnContainer) )
            }

            callback([NSNull(), containers])
        } catch let error as NSError {
            NSLog("Problem getting containers.")
            NSLog(error.localizedDescription)

            callback([error.localizedDescription, NSNull()])
        }
    }

    @objc func getGroups(_ callback: (NSArray) -> ()) -> Void {
        let contactStore = CNContactStore()
        do {
            var cNGroups = [CNGroup]()
            var cnContainers = [CNContainer]()
            try cNGroups = contactStore.groups(matching: nil)
            try cnContainers = contactStore.containers(matching: nil)
            var groups = [NSDictionary]();
            for cNGroup in cNGroups {
                groups.append( convertCNGroupToDictionary(cNGroup) )
            }

            callback([NSNull(), groups])
        } catch let error as NSError {
            NSLog("Problem getting groups.")
            NSLog(error.localizedDescription)

            callback([error.localizedDescription, NSNull()])
        }
    }

    @objc func contactsInGroup(_ identifier: String, callback: (NSArray) -> ()) -> Void {
      let contactStore = CNContactStore()
      do {
        var cNContacts = [CNContact]()

        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: identifier)
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch as [CNKeyDescriptor])

        fetchRequest.predicate = predicate
        fetchRequest.sortOrder = CNContactSortOrder.userDefault

        try contactStore.enumerateContacts(with: fetchRequest) { (cNContact, pointer) -> Void in
          cNContacts.append(cNContact)
        }

        var contacts = [NSDictionary]();
        for cNContact in cNContacts {
          contacts.append( convertCNContactToDictionary(cNContact) )
        }

        callback([NSNull(), contacts])
      } catch let error as NSError {
        NSLog("Problem getting contacts.")
        NSLog(error.localizedDescription)

        callback([error.localizedDescription, NSNull()])
      }
    }
  
    @objc func contactsInContainer(_ identifier: String, callback: (NSArray) -> ()) -> Void {
      let contactStore = CNContactStore()
      do {
        var cNContacts = [CNContact]()

        let predicate = CNContact.predicateForContactsInContainer(withIdentifier: identifier)
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch as [CNKeyDescriptor])

        fetchRequest.predicate = predicate
        fetchRequest.sortOrder = CNContactSortOrder.userDefault

        try contactStore.enumerateContacts(with: fetchRequest) { (cNContact, pointer) -> Void in
          cNContacts.append(cNContact)
        }

        var contacts = [NSDictionary]();
        for cNContact in cNContacts {
          contacts.append( convertCNContactToDictionary(cNContact) )
        }

        callback([NSNull(), contacts])
      } catch let error as NSError {
        NSLog("Problem getting contacts.")
        NSLog(error.localizedDescription)

        callback([error.localizedDescription, NSNull()])
      }
    }

    @objc func searchContacts(_ searchText: String?, callback: (NSArray) -> ()) -> Void {
        let contactStore = CNContactStore()
        do {
            var cNContacts = [CNContact]()

            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch as [CNKeyDescriptor])

            fetchRequest.sortOrder = CNContactSortOrder.givenName

            try contactStore.enumerateContacts(with: fetchRequest) { (cNContact, pointer) -> Void in
                if searchText == nil {
                    // Add all Contacts if no searchText is provided.
                    cNContacts.append(cNContact)
                } else {
                    // If the Contact contains the search string then add it.
                    if self.contactContainsText( cNContact, searchText: searchText! ) {
                        cNContacts.append(cNContact)
                    }
                }
            }

            var contacts = [NSDictionary]();
            for cNContact in cNContacts {
                contacts.append( convertCNContactToDictionary(cNContact) )
            }

            callback([NSNull(), contacts])
        } catch let error as NSError {
            NSLog("Problem getting contacts.")
            NSLog(error.localizedDescription)

            callback([error.localizedDescription, NSNull()])
        }
    }

    @objc func addContact(_ containerIdentifier: String, contactData: NSDictionary, callback: (NSArray) -> () ) -> Void {

        let contactStore   = CNContactStore()
        let mutableContact = CNMutableContact()
        let saveRequest    = CNSaveRequest()

        // TODO: Extend method to handle more fields.
        //
        if (contactData["givenName"] != nil) {
            mutableContact.givenName = contactData["givenName"] as! String
        }

        if (contactData["familyName"] != nil) {
            mutableContact.familyName = contactData["familyName"] as! String
        }
      
        if (contactData["departmentName"] != nil) {
            mutableContact.departmentName = contactData["departmentName"] as! String
        }
      
        if (contactData["jobTitle"] != nil) {
            mutableContact.jobTitle = contactData["jobTitle"] as! String
        }
      
        if (contactData["note"] != nil) {
            mutableContact.note = contactData["note"] as! String
        }

        if (contactData["organizationName"] != nil) {
            mutableContact.organizationName = contactData["organizationName"] as! String
        }
        
        if (contactData["imageData"] != nil) {
            mutableContact.imageData = Data(base64Encoded: contactData["imageData"] as! String)
        }

        for phoneNumber in contactData["phoneNumbers"] as! NSArray {
            let phoneNumberAsCNLabeledValue = convertPhoneNumberToCNLabeledValue( phoneNumber as! NSDictionary )

            mutableContact.phoneNumbers.append( phoneNumberAsCNLabeledValue )
        }

        for emailAddress in contactData["emailAddresses"] as! NSArray {
            let emailAddressAsCNLabeledValue = convertEmailAddressToCNLabeledValue ( emailAddress as! NSDictionary )

            mutableContact.emailAddresses.append( emailAddressAsCNLabeledValue )
        }

        for postalAddress in contactData["postalAddresses"] as! NSArray {
            let postalAddressAsCNLabeledValue = convertPostalAddressToCNLabeledValue ( postalAddress as! NSDictionary )

            mutableContact.postalAddresses.append( postalAddressAsCNLabeledValue )
        }

        do {

            saveRequest.add(mutableContact, toContainerWithIdentifier:containerIdentifier)

            try contactStore.execute(saveRequest)

            callback( [NSNull(), true] )

        }
        catch let error as NSError {
            NSLog("Problem creating contact.")
            NSLog(error.localizedDescription)

            callback( [error.localizedDescription, false] )
        }

    }

    @objc func addGroup(_ groupData: NSDictionary, callback: (NSArray) -> () ) -> Void {

        let contactStore   = CNContactStore()
        let mutableGroup = CNMutableGroup()
        let saveRequest    = CNSaveRequest()

        if (groupData["name"] != nil) {
          mutableGroup.name = groupData["name"] as! String
        }

        do {
          saveRequest.add(mutableGroup, toContainerWithIdentifier:nil)

          try contactStore.execute(saveRequest)

          callback( [NSNull(), true] )
        }
        catch let error as NSError {
            NSLog("Problem creating group.")
            NSLog(error.localizedDescription)

            callback( [error.localizedDescription, false] )
        }

    }

    @objc func updateContact(_ identifier: String, contactData: NSDictionary, callback: (NSArray) -> () ) -> Void {

        let contactStore = CNContactStore()

        let saveRequest = CNSaveRequest()

        let cNContact = getCNContact(identifier, keysToFetch: keysToFetch as [CNKeyDescriptor])

        let mutableContact = cNContact!.mutableCopy() as! CNMutableContact

        if ( contactData["givenName"] != nil ) {
            mutableContact.givenName = contactData["givenName"] as! String
        }

        if ( contactData["familyName"] != nil ) {
            mutableContact.familyName = contactData["familyName"] as! String
        }

        if ( contactData["organizationName"] != nil ) {
            mutableContact.organizationName = contactData["organizationName"] as! String
        }

        if ( contactData["phoneNumbers"] != nil ) {
            mutableContact.phoneNumbers.removeAll()

            for phoneNumber in contactData["phoneNumbers"] as! NSArray {
                let phoneNumberAsCNLabeledValue = convertPhoneNumberToCNLabeledValue( phoneNumber as! NSDictionary )

                mutableContact.phoneNumbers.append( phoneNumberAsCNLabeledValue )
            }
        }

        if ( contactData["emailAddresses"] != nil ) {
            mutableContact.emailAddresses.removeAll()

            for emailAddress in contactData["emailAddresses"] as! NSArray {
                let emailAddressAsCNLabeledValue = convertEmailAddressToCNLabeledValue ( emailAddress as! NSDictionary )

                mutableContact.emailAddresses.append( emailAddressAsCNLabeledValue )
            }
        }

        if ( contactData["postalAddresses"] != nil ) {
            mutableContact.postalAddresses.removeAll()

            for postalAddress in contactData["postalAddresses"] as! NSArray {
                let postalAddressAsCNLabeledValue = convertPostalAddressToCNLabeledValue ( postalAddress as! NSDictionary )

                mutableContact.postalAddresses.append( postalAddressAsCNLabeledValue )
            }
        }


        do {

            saveRequest.update(mutableContact)

            try contactStore.execute(saveRequest)

            callback( [NSNull(), true] )

        }
        catch let error as NSError {
            NSLog("Problem updating Contact with identifier: " + identifier)
            NSLog(error.localizedDescription)

            callback( [error.localizedDescription, false] )
        }


    }

    @objc func updateGroup(_ identifier: String, groupData: NSDictionary, callback: (NSArray) -> () ) -> Void {

      let contactStore = CNContactStore()

      let saveRequest = CNSaveRequest()

      let cNGroup = getCNGroup(identifier)

      let mutableGroup = cNGroup!.mutableCopy() as! CNMutableGroup

      if ( groupData["name"] != nil ) {
        mutableGroup.name = groupData["name"] as! String
      }

      do {
        saveRequest.update(mutableGroup)

        try contactStore.execute(saveRequest)

        callback( [NSNull(), true] )
      }
      catch let error as NSError {
        NSLog("Problem updating group with identifier: " + identifier)
        NSLog(error.localizedDescription)

        callback( [error.localizedDescription, false] )
      }
    }

    @objc func deleteContact(_ identifier: String, callback: (NSArray) -> () ) -> Void {

        let contactStore = CNContactStore()

        let cNContact = getCNContact( identifier, keysToFetch: keysToFetch as [CNKeyDescriptor] )

        let saveRequest = CNSaveRequest()

        let mutableContact = cNContact!.mutableCopy() as! CNMutableContact

        saveRequest.delete(mutableContact)

        do {

            try contactStore.execute(saveRequest)

            callback( [NSNull(), true] )

        }
        catch let error as NSError {

            NSLog("Problem deleting unified contact with identifier: " + identifier)
            NSLog(error.localizedDescription)

            callback( [error.localizedDescription, false] )
        }

    }

    @objc func deleteGroup(_ identifier: String, callback: (NSArray) -> () ) -> Void {

      let contactStore = CNContactStore()

      let cNGroup = getCNGroup(identifier)

      let saveRequest = CNSaveRequest()

      let mutableGroup = cNGroup!.mutableCopy() as! CNMutableGroup

      saveRequest.delete(mutableGroup)

      do {
        try contactStore.execute(saveRequest)
        callback( [NSNull(), true] )
      }
      catch let error as NSError {
        NSLog("Problem deleting group with identifier: " + identifier)
        NSLog(error.localizedDescription)

        callback( [error.localizedDescription, false] )
      }

    }

    @objc func addContactsToGroup(_ identifier: String, contactIdentifiers: [NSString], callback: (NSArray) -> () ) -> Void {
      let contactStore = CNContactStore()
      let cNGroup = getCNGroup(identifier)
      let saveRequest = CNSaveRequest()
      let mutableGroup = cNGroup!.mutableCopy() as! CNMutableGroup

      do {
        for contactIdentifier in contactIdentifiers {
          let cNContact = getCNContact(contactIdentifier as String, keysToFetch: keysToFetch as [CNKeyDescriptor])
          let mutableContact = cNContact!.mutableCopy() as! CNMutableContact

          saveRequest.addMember(mutableContact, to: mutableGroup)
        }

        try contactStore.execute(saveRequest)
        callback( [NSNull(), true] )
      }
      catch let error as NSError {
        NSLog("Problem adding contacts to group with identifier: " + identifier)
        NSLog(error.localizedDescription)

        callback( [error.localizedDescription, false] )
      }
    }
  
    @objc func addContactsToContainer(_ identifier: String, contactIdentifiers: [NSString], callback: (NSArray) -> () ) -> Void {
      let contactStore = CNContactStore()
      let saveRequest = CNSaveRequest()

      do {
        for contactIdentifier in contactIdentifiers {
          let cNContact = getCNContact(contactIdentifier as String, keysToFetch: keysToFetch as [CNKeyDescriptor])
          let mutableContact = cNContact!.mutableCopy() as! CNMutableContact

          saveRequest.add(mutableContact, toContainerWithIdentifier:identifier)
        }

        try contactStore.execute(saveRequest)
        callback( [NSNull(), true] )
      }
      catch let error as NSError {
        NSLog("Problem adding contacts to container with identifier: " + identifier)
        NSLog(error.localizedDescription)

        callback( [error.localizedDescription, false] )
      }
    }

    @objc func removeContactsFromGroup(_ identifier: String, contactIdentifiers: [NSString], callback: (NSArray) -> () ) -> Void {
      let contactStore = CNContactStore()
      let cNGroup = getCNGroup(identifier)
      let saveRequest = CNSaveRequest()
      let mutableGroup = cNGroup!.mutableCopy() as! CNMutableGroup

      do {
        for contactIdentifier in contactIdentifiers {
          let cNContact = getCNContact(contactIdentifier as String, keysToFetch: keysToFetch as [CNKeyDescriptor])
          let mutableContact = cNContact!.mutableCopy() as! CNMutableContact

          saveRequest.removeMember(mutableContact, from: mutableGroup)
        }

        try contactStore.execute(saveRequest)
        callback( [NSNull(), true] )
      }
      catch let error as NSError {
        NSLog("Problem removing contacts from group with identifier: " + identifier)
        NSLog(error.localizedDescription)

        callback( [error.localizedDescription, false] )
      }
    }

    /////////////
    // PRIVATE //

    func getCNContact( _ identifier: String, keysToFetch: [CNKeyDescriptor] ) -> CNContact? {
      let contactStore = CNContactStore()
      do {
        let cNContact = try contactStore.unifiedContact( withIdentifier: identifier, keysToFetch: keysToFetch )
        return cNContact
      } catch let error as NSError {
        NSLog("Problem getting unified contact with identifier: " + identifier)
        NSLog(error.localizedDescription)
        return nil
      }
    }

    func getCNGroup( _ identifier: String ) -> CNGroup? {
      let contactStore = CNContactStore()
      do {
        let predicate = CNGroup.predicateForGroups(withIdentifiers: [identifier])
        let cNGroup = try contactStore.groups(matching: predicate).first
        return cNGroup
      } catch let error as NSError {
        NSLog("Problem getting group with identifier: " + identifier)
        NSLog(error.localizedDescription)
        return nil
      }
    }
  
    func getCNContainer( _ identifier: String ) -> CNContainer? {
      let contactStore = CNContactStore()
      do {
        let predicate = CNContainer.predicateForContainers(withIdentifiers: [identifier])
        let cNContainer = try contactStore.containers(matching: predicate).first
        return cNContainer
      } catch let error as NSError {
        NSLog("Problem getting container with identifier: " + identifier)
        NSLog(error.localizedDescription)
        return nil
      }
    }

    func contactContainsText( _ cNContact: CNContact, searchText: String ) -> Bool {
        let searchText   = searchText.lowercased();
        let textToSearch = cNContact.givenName.lowercased() + " " + cNContact.familyName.lowercased() + " " + cNContact.nickname.lowercased()

        if searchText.isEmpty || textToSearch.contains(searchText) {
            return true
        } else {
            return false
        }
    }

    func getLabeledDict<T>(_ item: CNLabeledValue<T>) -> [String: Any] {
        var dict = [String: Any]()
        dict["identifier"] = item.identifier
        if let label = item.label {
            if label.hasPrefix("_$!<") && label.hasSuffix(">!$_") {
                addString(&dict, key: "label", value: label.substring(with: label.index(label.startIndex, offsetBy: 4)..<label.index(label.endIndex, offsetBy: -4)))
            } else {
                addString(&dict, key: "label", value: item.label)
            }
        }
        addString(&dict, key: "localizedLabel", value: item.label == nil ? nil : CNLabeledValue<T>.localizedString(forLabel: item.label!))
        return dict
    }

    func addString(_ dict: inout [String: Any], key: String, value: String?) {
        if let value = value, !value.isEmpty {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if (!trimmed.isEmpty) {
                dict[key] = value
            }
        }
    }

    func convertCNGroupToDictionary(_ cNGroup: CNGroup) -> NSDictionary {
        var group = [String: Any]()

        addString(&group, key: "identifier", value: cNGroup.identifier)
        addString(&group, key: "name", value: cNGroup.name)
        return group as NSDictionary
    }
  
    func convertCNContainerToDictionary(_ cNContainer: CNContainer) -> NSDictionary {
        var container = [String: Any]()

        addString(&container, key: "identifier", value: cNContainer.identifier)
        addString(&container, key: "name", value: cNContainer.name)
        addString(&container, key: "externalIdentifier", value: cNContainer.value(forKey: "externalIdentifier") as? String)

        return container as NSDictionary
    }

    func convertCNContactToDictionary(_ cNContact: CNContact) -> NSDictionary {
        var contact = [String: Any]()

        if let birthday = cNContact.birthday {
            var date = [String: Int]()
            date["year"] = birthday.year == NSDateComponentUndefined ? nil : birthday.year
            date["month"] = birthday.month == NSDateComponentUndefined ? nil : birthday.month
            date["day"] = birthday.day == NSDateComponentUndefined ? nil : birthday.day
            contact["birthday"] = date
        }

        if cNContact.contactRelations.count > 0 {
            contact["contactRelations"] = cNContact.contactRelations.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "name", value: item.value.name)
                return dict
            }
        }

        addString(&contact, key: "contactType", value: cNContact.contactType == CNContactType.person ? "person" : "organization")

        if cNContact.dates.count > 0 {
            contact["dates"] = cNContact.dates.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                dict["year"] = item.value.year == NSDateComponentUndefined ? nil : item.value.year
                dict["month"] = item.value.month == NSDateComponentUndefined ? nil : item.value.month
                dict["day"] = item.value.day == NSDateComponentUndefined ? nil : item.value.day
                return dict
            }
        }

        addString(&contact, key: "departmentName", value: cNContact.departmentName)

        if cNContact.emailAddresses.count > 0 {
            contact["emailAddresses"] = cNContact.emailAddresses.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "value", value: item.value as String)
                return dict
            }
        }

        addString(&contact, key: "familyName", value: cNContact.familyName)
        addString(&contact, key: "givenName", value: cNContact.givenName)
        addString(&contact, key: "identifier", value: cNContact.identifier)

        contact["imageDataAvailable"] = cNContact.imageDataAvailable

        if cNContact.instantMessageAddresses.count > 0 {
            contact["instantMessageAddresses"] = cNContact.instantMessageAddresses.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "service", value: item.value.service)
                addString(&dict, key: "localizedService", value: CNInstantMessageAddress.localizedString(forService: item.value.service))
                addString(&dict, key: "username", value: item.value.username)
                return dict
            }
        }

        addString(&contact, key: "jobTitle", value: cNContact.jobTitle)
        addString(&contact, key: "middleName", value: cNContact.middleName)
        addString(&contact, key: "namePrefix", value: cNContact.namePrefix)
        addString(&contact, key: "nameSuffix", value: cNContact.nameSuffix)
        addString(&contact, key: "nickname", value: cNContact.nickname)

        if let nonGregorianBirthday = cNContact.nonGregorianBirthday {
            var date = [String: Int]()
            date["year"] = nonGregorianBirthday.year == NSDateComponentUndefined ? nil : nonGregorianBirthday.year
            date["month"] = nonGregorianBirthday.month == NSDateComponentUndefined ? nil : nonGregorianBirthday.month
            date["day"] = nonGregorianBirthday.day == NSDateComponentUndefined ? nil : nonGregorianBirthday.day
            contact["nonGregorianBirthday"] = date
        }

        // addString(&contact, key: "note", value: cNContact.note) // NOTE: iOS 13 does not allow fetching of notes without the com.apple.developer.contacts.notes entitlement, which requires special permission from Apple.
        addString(&contact, key: "organizationName", value: cNContact.organizationName)

        if cNContact.phoneNumbers.count > 0 {
            contact["phoneNumbers"] = cNContact.phoneNumbers.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "stringValue", value: item.value.stringValue)
                addString(&dict, key: "countryCode", value: item.value.value(forKey: "countryCode") as? String)
                addString(&dict, key: "digits", value: item.value.value(forKey: "digits") as? String)
                return dict
            }
        }

        addString(&contact, key: "phoneticFamilyName", value: cNContact.phoneticFamilyName)
        addString(&contact, key: "phoneticGivenName", value: cNContact.phoneticGivenName)
        addString(&contact, key: "phoneticMiddleName", value: cNContact.phoneticMiddleName)

        // if #available(iOS 10.0, *) {
        //   contact["phoneticOrganizationName"]   = cNContact.phoneticOrganizationName
        // } else {
        //   // Fallback on earlier versions
        // }

        if cNContact.postalAddresses.count > 0 {
            contact["postalAddresses"] = cNContact.postalAddresses.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "street", value: item.value.street)
                addString(&dict, key: "city", value: item.value.city)
                addString(&dict, key: "state", value: item.value.state)
                addString(&dict, key: "postalCode", value: item.value.postalCode)
                addString(&dict, key: "country", value: item.value.country)
                addString(&dict, key: "isoCountryCode", value: item.value.isoCountryCode)
                addString(&dict, key: "mailingAddress", value: CNPostalAddressFormatter.string(from: item.value, style: .mailingAddress))
                return dict
            }
        }

        addString(&contact, key: "previousFamilyName", value: cNContact.previousFamilyName)

        if cNContact.socialProfiles.count > 0 {
            contact["socialProfiles"] = cNContact.socialProfiles.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "urlString", value: item.value.urlString)
                addString(&dict, key: "username", value: item.value.username)
                addString(&dict, key: "userIdentifier", value: item.value.userIdentifier)
                addString(&dict, key: "service", value: item.value.service)
                addString(&dict, key: "localizedService", value: CNSocialProfile.localizedString(forService: item.value.service))
                return dict
            }
        }

        if let thumbnailImageData = cNContact.thumbnailImageData {
            addString(&contact, key: "thumbnailImageData", value: thumbnailImageData.base64EncodedString(options: []))
        }

        if cNContact.urlAddresses.count > 0 {
            contact["urlAddresses"] = cNContact.urlAddresses.map { (item) -> [String: Any] in
                var dict = getLabeledDict(item)
                addString(&dict, key: "value", value: item.value as String)
                return dict
            }
        }

        addString(&contact, key: "fullName", value: CNContactFormatter.string( from: cNContact, style: .fullName ))

        return contact as NSDictionary
    }

    func convertPhoneNumberToCNLabeledValue(_ phoneNumber: NSDictionary) -> CNLabeledValue<CNPhoneNumber> {
        var formattedLabel = String()
        let userProvidedLabel = phoneNumber["label"] as! String
        let lowercaseUserProvidedLabel = userProvidedLabel.lowercased()
        switch (lowercaseUserProvidedLabel) {
        case "home":
            formattedLabel = CNLabelHome
        case "work":
            formattedLabel = CNLabelWork
        case "mobile":
            formattedLabel = CNLabelPhoneNumberMobile
        case "iphone":
            formattedLabel = CNLabelPhoneNumberiPhone
        case "main":
            formattedLabel = CNLabelPhoneNumberMain
        case "home fax":
            formattedLabel = CNLabelPhoneNumberHomeFax
        case "work fax":
            formattedLabel = CNLabelPhoneNumberWorkFax
        case "pager":
            formattedLabel = CNLabelPhoneNumberPager
        case "other":
            formattedLabel = CNLabelOther
        default:
            formattedLabel = userProvidedLabel
        }

        return CNLabeledValue(
            label:formattedLabel,
            value:CNPhoneNumber(stringValue: phoneNumber["stringValue"] as! String)
        )
    }

    func convertEmailAddressToCNLabeledValue(_ emailAddress: NSDictionary) -> CNLabeledValue<NSString> {
        var formattedLabel = String()
        let userProvidedLabel = emailAddress["label"] as! String
        let lowercaseUserProvidedLabel = userProvidedLabel.lowercased()
        switch (lowercaseUserProvidedLabel) {
        case "home":
            formattedLabel = CNLabelHome
        case "work":
            formattedLabel = CNLabelWork
        case "icloud":
            formattedLabel = CNLabelEmailiCloud
        case "other":
            formattedLabel = CNLabelOther
        default:
            formattedLabel = userProvidedLabel
        }

        return CNLabeledValue(
            label:formattedLabel,
            value: emailAddress["value"] as! NSString
        )
    }

    func convertPostalAddressToCNLabeledValue(_ postalAddress: NSDictionary) -> CNLabeledValue<CNPostalAddress> {
        var formattedLabel = String()
        let userProvidedLabel = postalAddress["label"] as! String
        let lowercaseUserProvidedLabel = userProvidedLabel.lowercased()
        switch (lowercaseUserProvidedLabel) {
        case "home":
            formattedLabel = CNLabelHome
        case "work":
            formattedLabel = CNLabelWork
        case "other":
            formattedLabel = CNLabelOther
        default:
            formattedLabel = userProvidedLabel
        }

        let mutableAddress = CNMutablePostalAddress()
        mutableAddress.street = postalAddress["street"] as? String ?? ""
        mutableAddress.city = postalAddress["city"] as? String ?? ""
        mutableAddress.state = postalAddress["state"] as? String ?? ""
        mutableAddress.postalCode = postalAddress["postalCode"] as? String ?? ""
        mutableAddress.country = postalAddress["country"] as? String ?? ""
 
        return CNLabeledValue(
            label: formattedLabel,
            value: mutableAddress as CNPostalAddress
        )
    }

}
