/**
 * Created by henri on 04.10.2021.
 */
@IsTest
public with sharing class VisualEditorUtility_Test {

    @TestSetup
    static void setup() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Account ' + i));
        }
        insert accounts;

        List<Asset> assets = new List<Asset>();
        for (Account account : accounts) {
            for (Integer i = 0; i < 5; i++) {
                assets.add(new Asset(Name = 'Asset' + i, AccountId = account.Id, Status = 'Active'));
            }
        }
        insert assets;
    }

    @IsTest
    static void visualEditorUtilityTestPositive() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        Account account = (accounts.size() == 1) ? accounts.get(0) : null;

        VisualEditorUtility.DataTable dataTable;
        Test.startTest();
        {
            List<VisualEditor.DataRow> rows = VisualEditorUtility.createRowsBasedOnEntity('Account');
            for (VisualEditor.DataRow dataRow : rows) {
                if (dataRow.getLabel() == 'Assets') {
                    System.debug(dataRow);
                    dataTable = VisualEditorUtility.getDatatable(account.Id, dataRow.getValue().toString(), 'Name,Account.Name,Owner.Name,CreatedBy.Name', 0, 2);
                    dataTable.data.addAll(VisualEditorUtility.getDatatable(account.Id, dataRow.getValue().toString(), 'Name,Account.Name,Owner.Name,CreatedBy.Name', 2, 3).data);
                    break;
                }
            }
        }
        Test.stopTest();

        System.assertNotEquals(null, dataTable);
    }

    @IsTest
    static void visualEditorUtilityTestNegative() {
        VisualEditorUtility.DataTable dataTable;
        Exception ex1;
        Test.startTest();
        {
            try {
                dataTable = VisualEditorUtility.getDatatable('', 'Asset&AccountId', 'invalidFieldNameOrSomethingIDontKnowPleaseLetThisNotBeAField', 0, 0);
            } catch (Exception e) {
                ex1 = e;
            }
        }
        Test.stopTest();

        System.assertEquals(null, dataTable);
        System.assertNotEquals(null, ex1);
    }
}