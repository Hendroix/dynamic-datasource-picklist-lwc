/**
 * Created by henri on 03.10.2021.
 */

import { LightningElement, api, wire } from 'lwc';
import getDatatable from '@salesforce/apex/VisualEditorUtility.getDatatable';

export default class DynamicDatasourcePicklist extends LightningElement {
    @api recordId;

    @api relationship;
    @api fields;

    columns;
    data = [];
    maxRows;
    query;

    error;
    isLoading = false;

    connectedCallback(){
        console.log(this.recordId, this.relationship, this.fields);
        this.isLoading = true;
        getDatatable({recordId: this.recordId, relationship: this.relationship, CSF: this.fields, offset: 0})
        .then(datatable => {
            console.log(datatable);

            this.columns = datatable.columns;
            this.maxRows = datatable.maxRows;
            this.data = [...this.data, ...this.injectUrlNavigationUrls(datatable.data, datatable.columns)];
            this.query = datatable.query;

            if(this.data.length < this.maxRows){
                let datatable = this.template.querySelector('lightning-datatable');
                if(datatable){
                    datatable.enableInfiniteLoading = true;
                }
            }
        })
        .catch(error => {
            console.error(error);
            this.error = error.body?.message;
        })
        .finally(this.isLoading = false);
    }

    injectUrlNavigationUrls(records, columns){
        records.forEach(record => {
            columns.forEach(column => {
                if(column.isNavigationColumn && record[column.navigationRecordIdFieldName]){
                    if(column.parentObjectCanBeMultiple) this.replaceObjectTypeInUrl(record, column);

                    record[column.fieldName] = column.urlFormat.replace('[Id]', record[column.navigationRecordIdFieldName]);

                    if(column.flattenedField){
                        let depth = column.flattenedField.split('.');
                        record[column.flattenedField] = this.extractFieldValue(record, depth, 0);
                    }
                }
            })
        });
        return records;
    }

    extractFieldValue(record, array, index){
        if((array.length - 1) <= index){
            return record[array[index]];
        } else {
            return this.extractFieldValue(record[array[index]], array, index + 1);
        }
    }

    replaceObjectTypeInUrl(record, column){
        if(record[column.navigationRecordIdFieldName].startsWith('005')){
            console.log(column.urlFormat);
            column.urlFormat = column.urlFormat.replace(/r\/.*\/\[/, 'r/User/[');
            console.log(column.urlFormat);
        }else if(record[column.navigationRecordIdFieldName].startsWith('00G')){
            column.urlFormat = column.urlFormat.replace(/r\/.*\/\[/, 'r/Group/[');
        }
    }

    handleLoadMore(event){
        if(this.isLoading) return;
        event.target.isLoading = true;
        getDatatable({recordId: this.recordId, relationship: this.relationship, CSF: this.fields, offset: this.data.length})
        .then(datatable => {
            console.log(datatable);
            this.data = [...this.data, ...this.injectUrlNavigationUrls(datatable.data, this.columns)];
            this.query = datatable.query;
            if(this.data.length >= this.maxRows){
                let datatable = this.template.querySelector('lightning-datatable');
                if(datatable){
                    datatable.enableInfiniteLoading = false;
                }
            }
        })
        .catch(error => {
            console.error(error);
            this.error = error.body?.message;
        })
        .finally(() => {
            let datatable = this.template.querySelector('lightning-datatable');
            if(datatable){
                setTimeout(() => {
                    datatable.isLoading = false;
                }, 2000)
            }
        });
    }

    get datatableHeightRestriction(){
        return this.data?.length > 6 ? 'height: 12rem;' : 'max-height: 12rem;';
    }

    get hasData(){
        return this.data?.length > 0;
    }

    get showingOfTitle(){
        return `Showing ${this.data?.length} of ${this.maxRows}`;
    }
}