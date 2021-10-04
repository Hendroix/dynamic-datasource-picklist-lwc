/**
 * Created by henri on 04.10.2021.
 */
@IsTest
public with sharing class MyCustomPicklist_Test {

    @IsTest
    static void testDynamicPicklist(){
        VisualEditor.DynamicPickListRows rows;
        VisualEditor.DataRow defaultRow;
        Test.startTest();
        {
            VisualEditor.DesignTimePageContext context = new VisualEditor.DesignTimePageContext();
            context.entityName = 'Account';
            MyCustomPicklist myCustomPicklist = new MyCustomPicklist(context);
            rows = myCustomPicklist.getValues();
            defaultRow = myCustomPicklist.getDefaultValue();
            myCustomPicklist.isValid('');
        }
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertNotEquals(null, defaultRow);
    }
}