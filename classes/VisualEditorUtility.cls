/**
 * Created by henri on 03.10.2021.
 */
public with sharing class VisualEditorUtility {

    private static final String DELIMITER = '&';
    private static final Integer SOQL_QUERY_LIMIT = 15;

    private static Map<String, Map<String, SObjectField>> sObjectFieldMapBySObject {
        get {
            if (sObjectFieldMapBySObject == null) sObjectFieldMapBySObject = new Map<String, Map<String, SObjectField>>();
            return sObjectFieldMapBySObject;
        }
        set;
    }

    @AuraEnabled
    public static DataTable getDatatable(String recordId, String relationship, String CSF, Integer offset) {
        if (relationship.containsNone(DELIMITER)) throw new AuraHandledException('NO DELIMITER WAS GIVEN, API NAME CONTEXT IS LOST!');
        offset = offset != null ? offset : 0;
        return new DataTable(recordId, relationship.split(DELIMITER).get(0), relationship.split(DELIMITER).get(1), sanitizeFieldsString(CSF), offset);
    }

    private static List<String> sanitizeFieldsString(String csf) {
        csf = csf.deleteWhitespace();
        csf = String.escapeSingleQuotes(csf);
        return csf.split(',');
    }

    public static List<VisualEditor.DataRow> createRowsBasedOnEntity(String entityName) {
        List<VisualEditor.DataRow> dataRows = new List<VisualEditor.DataRow>();
        List<ChildRelationship> childRelationships = Schema.getGlobalDescribe().get(entityName).getDescribe().getChildRelationships();
        for (ChildRelationship childRelationship : childRelationships) {
            if (!childRelationship.isDeprecatedAndHidden() && childRelationship.getRelationshipName() != null) {
                dataRows.add(createRow(childRelationship.relationshipName, (childRelationship.getChildSObject() + DELIMITER + childRelationship.field.getDescribe().getName())));
            }
        }
        return dataRows;
    }

    public static VisualEditor.DataRow createRow(String value, String label) {
        return new VisualEditor.DataRow(value, label);
    }

    private static Map<String, SObjectField> getMap(String objectApiName) {
        if (sObjectFieldMapBySObject.containsKey(objectApiName)) {
            return sObjectFieldMapBySObject.get(objectApiName);
        }

        Map<String, SObjectField> labelMap = new Map<String, SObjectField>();
        for (SObjectField field : Schema.getGlobalDescribe().get(objectApiName).getDescribe(SObjectDescribeOptions.FULL).fields.getMap().values()) {
            labelMap.put(field.getDescribe().name.toLowerCase(), field);
        }
        sObjectFieldMapBySObject.put(objectApiName, labelMap);
        return labelMap;
    }

    private with sharing class DataTable {
        @AuraEnabled
        public List<Column> columns {
            get {
                if (this.columns == null) {
                    this.columns = new List<Column>();
                }
                return this.columns;
            }
            set;
        }
        @AuraEnabled
        public List<SObject> data;
        @AuraEnabled
        public Integer maxRows;
        @AuraEnabled
        public String query;
        private Boolean isFirst;

        public DataTable(String parentRecordId, String childObjectApiName, String parentRelationField, List<String> fields, Integer offset) {
            this.isFirst = offset == 0 || offset == null;

            setColumns(childObjectApiName, fields);
            setData(parentRecordId, childObjectApiName, parentRelationField, fields, offset);
            setMaxRows(childObjectApiName, parentRelationField, parentRecordId);
        }

        private void setMaxRows(String childObjectApiName, String parentRelationField, String parentRecordId) {
            //No need to define the columns each time. To "optimize" we only do it the first time.
            if (this.isFirst && this.maxRows == null) {
                this.maxRows = Database.countQuery('SELECT COUNT() FROM ' + childObjectApiName + ' WHERE ' + parentRelationField + ' = \'' + parentRecordId + '\'');
            }
        }

        private void setColumns(String childObjectApiName, List<String> fields) {
            //No need to define the columns each time. To "optimize" we only do it the first time.
            if (this.isFirst) {
                Map<String, SObjectField> labelMap = getMap(childObjectApiName);
                for (String field : fields) {
                    if (field.contains('__r') || field.contains('.')) {
                        handleRelatedField(childObjectApiName, field);
                    } else if (labelMap.containsKey(field.toLowerCase())) {
                        DescribeFieldResult fieldDefinition = labelMap.get(field.toLowerCase()).getDescribe();
                        this.columns.add(new Column(fieldDefinition, childObjectApiName));
                    } else {
                        throw new AuraHandledException('Given field ' + field + 'does not exists.');
                    }
                }
            }
        }

        private void handleRelatedField(String childObjectApiName, String field) {
            String relatedObjectField = field.split('\\.').get(0);
            String relatedObjectRelatedField = field.split('\\.').get(1);
            if (relatedObjectField.contains('__r')) relatedObjectField = relatedObjectField.replace('__r', '__c');
            if (!relatedObjectField.contains('__c')) relatedObjectField = relatedObjectField + 'Id';

            Map<String, SObjectField> childObjectLabelMap = getMap(childObjectApiName);
            String relatedObjectType = childObjectLabelMap.get(relatedObjectField.toLowerCase()).getDescribe().getReferenceTo()?.get(0).getDescribe().name;

            Map<String, SObjectField> labelMap = getMap(relatedObjectType);
            if (labelMap.containsKey(relatedObjectRelatedField.toLowerCase())) {
                DescribeFieldResult fieldDefinition = labelMap.get(relatedObjectRelatedField.toLowerCase()).getDescribe();
                this.columns.add(new Column(fieldDefinition, relatedObjectType).setFlattenedField(field).setNavigationRecordIdFieldName(relatedObjectField).setParentObjectCanBeMultiple(childObjectLabelMap.get(relatedObjectField.toLowerCase()).getDescribe().isNamePointing()));
            }
        }

        private void setData(String parentRecordId, String childObjectApiName, String parentRelationField, List<String> fields, Integer offset) {
            this.query = 'SELECT Id, ' + String.join(fields, ', ') + ' FROM ' + childObjectApiName + ' WHERE ' + parentRelationField + ' = \'' + parentRecordId + '\' ORDER BY LastModifiedDate DESC LIMIT ' + SOQL_QUERY_LIMIT + ' OFFSET ' + offset;
            this.data = Database.query(this.query);
            this.maxRows = this.data.size() == SOQL_QUERY_LIMIT ? null : this.data.size();
        }

    }

    private with sharing class Column {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public Map<String, Object> typeAttributes = new Map<String, Object>();
        @AuraEnabled
        public String urlFormat;
        @AuraEnabled
        public Boolean isNavigationColumn;
        @AuraEnabled
        public String navigationRecordIdFieldName;
        @AuraEnabled
        public String flattenedField;
        @AuraEnabled
        public Boolean parentObjectCanBeMultiple = false;

        public Column(DescribeFieldResult fieldDescription, String objectApiName) {
            this.label = fieldDescription.getLabel();
            this.fieldName = fieldDescription.getName();

            if (fieldDescription.isNameField()) {
                this.type = 'url';
                this.fieldName = 'urlId';
                this.urlFormat = Url.getOrgDomainUrl().toExternalForm() + '/lightning/r/' + objectApiName + '/[Id]/view';
                this.isNavigationColumn = true;
                this.navigationRecordIdFieldName = 'Id';
                this.typeAttributes.put('target', '_self');
                this.typeAttributes.put('label', new Map<String, String>{
                        'fieldName' => fieldDescription.getName()
                });
                this.typeAttributes.put('tooltip', new Map<String, String>{
                        'fieldName' => fieldDescription.getName()
                });
            } else {
                this.type = setType(fieldDescription.getType());
            }
        }

        private Column setFlattenedField(String flattenedField) {
            this.flattenedField = flattenedField;
            this.typeAttributes.put('label', new Map<String, String>{
                    'fieldName' => flattenedField
            });
            this.typeAttributes.put('tooltip', new Map<String, String>{
                    'fieldName' => flattenedField
            });
            this.fieldName = 'url' + flattenedField;
            return this;
        }

        private Column setNavigationRecordIdFieldName(String navigationRecordIdFieldName) {
            this.navigationRecordIdFieldName = navigationRecordIdFieldName;
            return this;
        }

        private String setType(DisplayType type) {
            switch on type {
                when STRING, PICKLIST {
                    return 'text';
                } when DATETIME {
                    this.typeAttributes.put('day', '2-digit');
                    this.typeAttributes.put('month', '2-digit');
                    this.typeAttributes.put('year', 'numeric');
                    this.typeAttributes.put('hour', '2-digit');
                    this.typeAttributes.put('minute', '2-digit');
                    return 'date';
                } when DATE {
                    this.typeAttributes.put('day', '2-digit');
                    this.typeAttributes.put('month', '2-digit');
                    this.typeAttributes.put('year', 'numeric');
                    return 'date-local';
                } when else {
                    System.debug(type + ' is not mapped');
                    return null;
                }
            }
        }

        private Column setParentObjectCanBeMultiple(Boolean bool) {
            this.parentObjectCanBeMultiple = bool;
            return this;
        }
    }

}