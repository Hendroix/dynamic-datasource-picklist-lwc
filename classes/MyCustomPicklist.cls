/**
 * Created by henri on 03.10.2021.
 */
global with sharing class MyCustomPicklist extends VisualEditor.DynamicPickList {
    VisualEditor.DesignTimePageContext context;

    global MyCustomPicklist(VisualEditor.DesignTimePageContext context) {
        this.context = context;
    }

    global override VisualEditor.DataRow getDefaultValue() {
        return VisualEditorUtility.createRowsBasedOnEntity(this.context.entityName).get(0);
    }

    global override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DynamicPickListRows dynamicPickList = new VisualEditor.DynamicPickListRows();
        dynamicPickList.addAllRows(VisualEditorUtility.createRowsBasedOnEntity(this.context.entityName));
        return dynamicPickList;
    }

    global Boolean isValid(String attr) {
        return true;
    }

}