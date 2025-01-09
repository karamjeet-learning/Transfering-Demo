@RestResource(urlMapping='/AadharMaskingDataAPI/*')
global class AadharMaskingDataPostAPI {
@testVisible
    private static String contentDocId ;
    @testVisible
    private static String base64data ;
    @testVisible
    private static String maskedStatus ;
    

    @HttpPost
    global static ResponseWrapper postAadharDocumentData( String contentDocumentId, String data, String status){
        ResponseWrapper response = new ResponseWrapper();
        UtilityBaseService objBaseUtilty = new UtilityBaseService();
        contentDocId = contentDocumentId;
        Base64data = data;
        maskedStatus = status;
        if(maskedStatus != null && !maskedStatus.trim().equalsIgnoreCase('Masked')){
            objBaseUtilty.createErrorLogRecord('Aadhar Masking API',true,contentDocumentId,maskedStatus,null,null,'AadharMaskingDataPostAPI');
            response = new ResponseWrapper('Success','Error Post Successfully');
            return response;
        }
        response = validateData();
        if(response.status == 'Error'){
            return response;
        }
        Savepoint sp = Database.setSavepoint();
        try{
            uploadMaskedDocument();
            
           
            objBaseUtilty.createErrorLogRecord('Aadhar Masking API',false,contentDocId,null,null,null,'AadharMaskingDataPostAPI');
            response = new ResponseWrapper('Success','');
        }catch(Exception ex){
            Database.RollBack(sp);
            objBaseUtilty.createErrorLogRecord('Aadhar Masking API',true,contentDocId,null,null,ex,'AadharMaskingDataPostAPI');
            response = new ResponseWrapper('Error',ex.getMessage());
        }

        return response;

    }
    @testVisible
    private static void uploadMaskedDocument(){
        List<SObject> upsertRec = new List<SObject>();
        List<ContentVersion> unmaskedDocument = ContentVersionSelector.getContentVersionFromContentDocumentList(new Set<Id>{contentDocId});
        if(unmaskedDocument.size() > 0){
            ContentVersion cVersion = new ContentVersion();
            cVersion.VersionData = EncodingUtil.base64Decode(base64data);
            cVersion.Title = addVersioninName(unmaskedDocument[0].Title);
            cVersion.ContentDocumentId = contentDocId;
            List<String> pathName;
            if(unmaskedDocument[0].PathOnClient != null ){
                pathName = unmaskedDocument[0].PathOnClient.split('\\.');
            }
            if(pathName.size() > 0){
                cVersion.PathOnClient = unmaskedDocument[0].PathOnClient.split('\\.')[0] + '.pdf';
            }
            cVersion.ContentLocation = unmaskedDocument[0].ContentLocation;
            cVersion.Masked__c = true;
            ContentVersionTriggerHandler.restrictContentVersionUpdateFromStandard = false; //BAF-6175 Changes
            upsertRec.add(cVersion);
            upsertRec.addAll(updateDocumentName());
            upsert upsertRec;            
            


        }


    }
    @testVisible
    private static List<Documents__c> updateDocumentName(){
        List<Documents__c> docListToBeUpdated;
        List<ContentDocumentLink> relatedContentDocumentlink = ContentDocumentLinkSelector.getContentDocumentLinkRec(new Set<Id>{contentdocId});
        Set<Id> linkedEntityId = new Set<Id>();
        for(ContentDocumentLink conDocLink : relatedContentDocumentlink){
            if(String.valueOf(conDocLink.LinkedEntityId.getSObjectType()) == 'Documents__c'){
                linkedEntityId.add(conDocLink.LinkedEntityId);
            }
        }
        if(linkedEntityId.size() > 0){
            docListToBeUpdated = DocumentsSelector.getDocumentsByIds(linkedEntityId).values();
            for(Documents__c doc : docListToBeUpdated){
                doc.DocumentName__c = addVersioninName(doc.DocumentName__c);
            }
            system.debug(docListToBeUpdated);
        }
        return docListToBeUpdated;
        
    }

    private static String addVersioninName(String docName){
        List<String> titlelst = docName.split('_');
            Integer versionNumber;
            if(titlelst.size()==4){
                versionNumber = Integer.valueOf(titlelst[3]); 
                versionNumber = versionNumber + 1;
                titlelst[3] = String.valueOf(versionNumber);
            }
            
            return  String.join(titlelst,'_');
    }
    

    private static ResponseWrapper validateData(){
        ResponseWrapper res = new ResponseWrapper();
        List<String> errors = new List<String>();
        if(String.isBlank(contentDocId)){
            res.status = 'Error';
            errors.add('contentDocumentId');
        }
        if(String.isBlank(base64data)){
            errors.add('data');
        }
        if(String.isBlank(maskedStatus)){
            errors.add('status');
        }
        if(errors.size()>0){
            res.status = 'Error';
            res.errorMessage = String.join(errors,',') + ' is Required.';
        }
        return res;
    }

    global class ResponseWrapper{
        public String status;
        public String errorMessage;
        public ResponseWrapper(){}
        public ResponseWrapper(String status, String errorMessage){
            this.status = status;
            this.errorMessage = errorMessage;
        }
    }
}