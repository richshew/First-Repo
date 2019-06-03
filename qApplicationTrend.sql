
/******************************************************************************************************************************
	*Disclaimer: The following sql script is not in production has been significantly modified from the original version so as to preserve the integrity of the original table, view, alias, and column names.
				 Significant values (constants) used in the evaluation of decision making company policy exceptions were intentionally obfuscated with ambiguous variables.

	Author(s) / Editor(s):   RS
	Date:     01.31.2018
	Template: (Updated) Consumer Application Trending Report (Monthly)
	Purpose:  Return Tons of information per application.

                                                      Version History

    ver 1.0 - RS - 01.31.2018  -  Updated Version Created.
    ver 2.0 - RS - 05.18.2018  -  Updated the code that evaluates the Application date on the AppDetailID level to point to the CreationDate column
								  of the View001 table.
	ver 4.0 - RS - 12.21.2018  -  Re-wrote 75% of old T-SQL code to better optimize report runtime.
	ver 5.0 - RS - 02.28.2019  -  Sucessfully optimized report runtime to < 10 minutes from originally up to 8+ hours of runtime.
******************************************************************************************************************************/ 

Set Transaction Isolation Level Read Uncommitted	--Suppresses any errors that originate from exclusive locks that would prevent the current transaction from reading rows not committed by other transactions. (Also Enables "Dirty Reads")
Set NOCOUNT ON										--Suppress the auto-display of rowcounts for increased performance/speed
Set Statistics Time On								--Displays number of milliseconds required to parse, compile, and execute each statement transaction block.

IF OBJECT_ID('tempdb.dbo.#HouseholdApplicants', 'U') IS NOT NULL
  Drop Table #HouseholdApplicants;
IF OBJECT_ID('tempdb.dbo.#Trending', 'U') IS NOT NULL
  Drop Table #Trending;


CREATE table #HouseholdApplicants (
AppID Int,
PartyID Int,
BeginDate datetime)

declare @IncludeJointNonSpouseFL nvarchar(20),
        @IncludeCoSignerFL nvarchar(20),
        @IncludeIndividualGuarantorFL nvarchar(20)

  set @IncludeJointNonSpouseFL = 
    dbo.f_SettingConfigByKeys(26,2,4,default,default,default,default,default,default)

  set @IncludeCoSignerFL = 
    dbo.f_SettingConfigByKeys(27,2,4,default,default,default,default,default,default)

  set @IncludeIndividualGuarantorFL = 
    dbo.f_SettingConfigByKeys(2022,2,4,default,default,default,default,default,default)

;WITH CTE_Base (AppID) as
(
	Select distinct ad.AppID
	from View001 ad
	where ad.AppDetailSavePointID = 0 and 
		  ad.loantypeid = 1
),
  --Common Table Expression to identify each Household Applicant by AppID, PartyID, BeginDate.
CTE_Household (AppID, PartyID, BeginDate) as
(
select ai.AppID,
		 ai.PartyID,
         ai.BeginDate
from View002 ai
    inner join View004 apapt on (ai.AppID = apapt.AppID and
                                              ai.PartyID = apapt.PartyID and
                                              apapt.AppPartyTypeID = 1)

Union

     select ai_spouse.AppID, ai_spouse.PartyID, ai_spouse.BeginDate
      from View002 ai_spouse
       inner join View004 apapt on (ai_spouse.AppID = apapt.AppID and
                                                 ai_spouse.PartyID = apapt.PartyID and
                                                 apapt.AppPartyTypeID = 2)
       inner join View005 pr on (ai_spouse.PartyID = pr.ChildPartyID and
                                           ai_spouse.BeginDate = pr.ChildBeginDate and
                                           pr.RelationshipTypeID = 1)
	 where pr.ParentPartyID in (select ai.PartyID
								from View002 ai
								inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1))
		   and pr.BeginDate in (select ai.BeginDate
								from View002 ai
								inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1))
Union

    select ai_spouse.AppID, ai_spouse.PartyID, ai_spouse.BeginDate
      from View002 ai_spouse
       inner join View004 apapt on (ai_spouse.AppID = apapt.AppID and
                                                 ai_spouse.PartyID = apapt.PartyID and
                                                 apapt.AppPartyTypeID = 2)
       inner join View005 pr on (ai_spouse.PartyID = pr.ParentPartyID and
                                           ai_spouse.BeginDate = pr.BeginDate and
                                           pr.RelationshipTypeID = 1)

	   where pr.ChildPartyID in (select ai.PartyID
								from View002 ai
								inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1))
		   and pr.ChildBeginDate in (select ai.BeginDate
									from View002 ai
									inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1))
Union


     select ai.AppID, ai.PartyID, ai.BeginDate
      from View002 ai
       inner join View004 apapt on ai.AppID = apapt.AppID and
                                                ai.PartyID = apapt.PartyID and
                                                apapt.AppPartyTypeID = 2
	  where exists (select 1 from View006 ac
					inner join View004 apapt on (ac.AppID = apapt.AppID and
                                                         ac.PartyID = apapt.PartyID and
                                                         apapt.AppPartyTypeID = 1)
					where ac.AppID = ai.AppID)

Union

    select ai.AppID, ai.PartyID, ai.BeginDate
      from View002 ai
       inner join View004 apapt on ai.AppID = apapt.AppID and
                                                ai.PartyID = apapt.PartyID
      where apapt.AppPartyTypeID = 2 and
            not exists (select 1 from View005 pr
                         where ai.PartyID = pr.ParentPartyID and
                               ai.BeginDate = pr.BeginDate and
                               pr.ChildPartyID in (select ai.PartyID
								from View002 ai
								inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1)) and
                               pr.ChildBeginDate in (select ai.BeginDate
									from View002 ai
									inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1)) and
                               pr.RelationshipTypeID = 1) and
            not exists (select 1 from View005 pr
                         where ai.PartyID = pr.ChildPartyID and
                               ai.BeginDate = pr.ChildBeginDate and
                               pr.ParentPartyID in (select ai.PartyID
								from View002 ai
								inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1)) and
                               pr.BeginDate in (select ai.BeginDate
									from View002 ai
									inner join View004 apapt on (ai.AppID = apapt.AppID and
																			  ai.PartyID = apapt.PartyID and
																			  apapt.AppPartyTypeID = 1)) and
              pr.RelationshipTypeID = 1) and
			(@IncludeJointNonSpouseFL = 1)

Union

     select ai.AppID, ai.PartyID, ai.BeginDate
      from View002 ai
       inner join View004 apapt on ai.AppID = apapt.AppID and
                                                ai.PartyID = apapt.PartyID
      where apapt.AppPartyTypeID = 3 and
		    (@IncludeCoSignerFL = 1)

Union

    select ai.AppID, ai.PartyID, ai.BeginDate
      from View002 ai
       inner join View004 apapt on (ai.AppID = apapt.AppID and
                                                ai.PartyID = apapt.PartyID)
      where apapt.AppPartyTypeID = 27 and
		    (@IncludeIndividualGuarantorFL = 1)
)
  --Temporary Table to identify each Household Applicant by AppID, PartyID, BeginDate.
Insert into #HouseholdApplicants 
select hh.AppID, hh.PartyID, hh.BeginDate
from CTE_Household hh
inner join CTE_Base ad ON (ad.AppID = hh.AppID)


CREATE table #Trending (
AppID Int,
AppDetailID Int,
AppDetailSavepointID Int,
ApplicationStart Datetime,
ComplMonth nvarchar(100),
FinancialQuarter nvarchar(100),
BookedDate Datetime,
BookedMonth nvarchar(100),
AppDetailSavePointName nvarchar(120),
ProductID Int,
ProductShortName nvarchar(120),
ProductGrouping nvarchar(120),
HomeEquityLL nvarchar(120),
LoansLines nvarchar(120),
IntroductoryRate Decimal(28,8),
AmountFinanced money,
InterestRate Decimal(28,8),
APR Decimal(28,8),
Term Int,
PaymentTypeName nvarchar(120),
TotalMonthlyPayment money,
AmountRequested	money,
Principal money,
FinanceCharge money,
TotalOfPayments money,
TotalScore Int,
FICO_Band nvarchar(100),
LoanToValue Decimal(23,8),
LTVBand nvarchar(100),
PotentialProductDebtToIncome decimal(28,8),
PotentialPaymentToIncome decimal(28,8),
CumulativeDTI Decimal(23,8),
DTI_Band nvarchar(120),
LoantypeID Int,
ConOrBus nvarchar(30),
DecisionStatusName nvarchar(120),
NewStatus nvarchar(120),
DecisionStatusDate datetime,
DecisionStatusDatev2 datetime,
DecisionMonth nvarchar(100),
Indicator45 Int,
AccountNumber nvarchar(120),
ContractReviewStatusName nvarchar(120),
ContractReviewStatusLastUpdatedByUserName nvarchar(20),
ContractReviewStatusLastUpdateDate datetime,
ActualClosingDate datetime,
ScheduledRescissionDate datetime,
DisbursementDate datetime,
MaturityDate datetime,
AnalystID Int,
AnalystFirstName nvarchar(120),
AnalystLastName nvarchar(120),
ServicingOfficerFirstName nvarchar(120),
ServicingOfficerLastName nvarchar(120),
ServicingOfficer nvarchar(120),
WorkFlowStatusID Int,
WorkFlowStatusName nvarchar(120),
RiskRatingName nvarchar(120),
RiskRatingDate Datetime,
ContractDate Datetime,
CreationDate Datetime,
CreatedByPartyID Int,
CreatedByUserName nvarchar(10),
LastUpdateDate Datetime,
LastUpdatedByPartyID Int,
LastUpdatedByUserName nvarchar(10),
Policy_DTI_Exc Int,
Policy_LTV_Exc Int,
Policy_SLTV_Exc Int,
Policy_FICO_Exc Int,
DTI_exc Int,
LTV_exc Int,
FICO_exc Int,
Pricing_exc Int,
Other_exc Int,
Collateral_exc Int,
Term_exc Int,
Total_Exc_Cust Int,
Total_Exc Int,
Exc_Count nvarchar(30),
SourceChannelID Int,
SourceChannelName nvarchar(120),
PrivateBank nvarchar(120),
District nvarchar(120),
Code nvarchar(120),
ChannelType nvarchar(120),
ChannelCity nvarchar(200),
autodecisionstatusname nvarchar(120),
InternetApps nvarchar(5),
chhd money, --CurrentHouseholdDebt
chhi money, --CurrentHouseholdIncome
chhppd money, --CurrentHouseholdPotentialProductDebt
PotentialDebt money, --Potential Debt (Grouped by AppID)
PIHeloc nvarchar(Max),
EmployeeFlag bit,
Market_mgr nvarchar(200),
CONSTRAINT PK_Trending_App1 PRIMARY KEY CLUSTERED (AppID, AppDetailID)
)

CREATE NONCLUSTERED INDEX IX_Trending_Code_chhi_ltv
   ON dbo.#Trending (Code ASC, chhi ASC, LoantoValue ASC);

Insert Into #Trending
select
ad.AppID,  
ad.AppDetailID,
ad.AppDetailSavepointID, 
AStart.ApplicationStart,
LEFT(DATENAME(MONTH, AStart.ApplicationStart),3) + ' ' + CAST(YEAR(AStart.ApplicationStart) AS VARCHAR) as ComplMonth,
'Q' + CAST(DatePart(q, AStart.ApplicationStart) AS VARCHAR) + ' ' + CAST(Year(AStart.ApplicationStart) AS VARCHAR) AS FinancialQuarter,
case when p.productID in (119,129,130) and 
		  Status_decision.Name like 'Approved' then Status_decision.LastUpdatedate
	 else AppDetailStatus_contractreview.LastUpdateDate
End as BookedDate,						
LEFT(DATENAME(MONTH, (case
						when p.productID in (119,129,130) and
						Status_decision.Name in ('Approved','Counteroffer') then Status_decision.LastUpdatedate
						Else AppDetailStatus_contractreview.LastUpdateDate
					  End)),3)
	+ ' ' + CAST(YEAR(case
						when p.productID in (119,129,130) and
						Status_decision.Name in ('Approved','Counteroffer') then Status_decision.LastUpdatedate
						else AppDetailStatus_contractreview.LastUpdateDate
					  End) AS VARCHAR) as BookedMonth,
luads.Name as AppDetailSavePointName, 
ad.ProductID,  
case when p.productID in (168,170) and
		  PIHeloc.FieldValue in ('Interest Only') then 'Int Only HELOC'
	 when AStart.ApplicationStart > '2017-08-23' and 
		  p.productID in (168,170) and
		  PIHeloc.FieldValue is null then 'Int Only HELOC'
	 when p.productID in (168,170) and
		  PIHeloc.FieldValue in ('Principal and Interest') then 'P & I HELOC'
	 when p.productID in (168,170) then 'Lock Option HELOC'
	 Else p.ShortName
End as ProductShortName, 
case when p.productID in (142,143) then 'Auto'												
	 when p.productID in (129,130) then 'Credit Card'										
	 when p.productID in (156,159) then 'Unsecured LOC'										
	 when p.productID in (144,163,164) then 'Unsecured Term'								
	 when p.productID in (138,140,141) then 'HEIL'											
	 when p.productID in (139,168,170) then 'HELOC'											
	 when p.productID in (133,145,146,147,148,149,158,161,162,166,167) then 'Other Secured'	
	 Else p.ShortName
end as ProductGrouping,
HomeEquityLL = null,
LoansLines = null,
ad.IntroductoryRate,
ad.FinancedAmt as AmountFinanced,
ad.ContractRate as InterestRate,  
ad.APR, 
ad.TermInMonths as Term, 
luct.Name as PaymentTypeName,  
ad.MonthlyPmt as TotalMonthlyPayment,
AppDetailRequestedAmount_sum.sum_RequestedAmount as AmountRequested,  
ad.Principal, 
ad.FinanceChargeAmt as FinanceCharge, 
ad.TotalOfPayments,
FICO.TotalScore,
case
	when FICO.TotalScore < @FICO3 then 'Under @FICO3'		
	when FICO.TotalScore between @FICO3 and @FICO9 then '@FICO3 - @FICO9'
	when FICO.TotalScore between @FICO8 and @FICO7 then '700 - @FICO7'
	when FICO.TotalScore >= @FICO6 then 'Over @FICO6'
	end as FICO_Band,
adcv.LTV as LoanToValue,
case					
	when adcv.LTV = 0 then 'No LTV'				
	when adcv.LTV > 0 AND adcv.LTV <= @DTI6 then 'Under 50.0'				
	when adcv.LTV > @DTI6 and adcv.LTV <= @LTV1 then '50.1 to 85.0'				
	when adcv.LTV > @LTV1 then 'Over 85.0'				
	else 'No LTV'				
	end as LTVBand,
PotentialProductDebtToIncome = null,
PotentialPaymentToIncome = null,
CumulativeDTI = null,
DTI_Band = null,
ad.LoantypeID,
case ad.LoanTypeID	
	when 1 then 'Consumer'
	when 2 then 'Business'
	else 'Other' 
End as ConOrBus,
Status_decision.Name as DecisionStatusName,  
case
	when Status_decision.Name in ('Approved','Counteroffer') and 
			(
				(status_contractreview.Name like 'Accept' and 
				 ad.AccountNumber is not null) 
				 OR 
				(p.productID in (119,129,130) and /* 'New Credit Card','Credit Card Increase','Business Credit Card' */
				 Status_decision.Name like 'Approved')
			)  
	then 'Booked'
	when Status_decision.Name in ('Approved','Aprvd. Rejected by Applicant') then 'Approved'
	when Status_decision.Name in ('Counteroffer','Counteroffer Rejected by Applicant') then 'Counteroffer'
	else Status_decision.Name
End as NewStatus,
Status_decision.LastUpdateDate as DecisionStatusDate,
Status_decision.DecisionStatusDatev2, Status_decision.DecisionMonth,
case When (Cast(Round((((DateDiff(s, Status_decision.DecisionStatusDatev2, AppDetailStatus_contractreview.LastUpdateDate))) / 86400.0), 2) as numeric(8,1))) >= 45 then 1 else 0 End as Indicator45,
ad.column1 as AccountNum,
status_contractreview.Name as ContractReviewStatusName, 
User_contractreviewlastupdated.UserName as ContractReviewStatusLastUpdatedByUserName, 
AppDetailStatus_contractreview.LastUpdateDate as ContractReviewStatusLastUpdateDate, 
ad.ActualClosingDate, 
ad.ScheduledRescissionDate,                                                  
ad.DisbursementDate, 
ad.MaturityDate,  
AppDetailParty_analyst.PartyID as AnalystID, 
Person_analyst.FirstName as AnalystFirstName, 
Person_analyst.LastName as AnalystLastName, 
Servicing.ServicingOfficerFirstName as ServicingOfficerFirstName, 
Servicing.ServicingOfficerLastName as ServicingOfficerLastName, 
Servicing.ServicingOfficerFirstName + ' ' + Servicing.ServicingOfficerLastName as ServicingOfficer,
AppDetailStatus_workflow.StatusID as WorkFlowStatusID,  
Status_workflow.Name as WorkFlowStatusName,                           
lurr.Name as RiskRatingName,  
ad.RiskRatingDate, 
ad.ContractDate, 
ad.CreationDate,  
ad.CreatedByPartyID,  
chhcbpi.Username as CreatedByUserName,
ad.LastUpdateDate,
ad.LastUpdatedByPartyID, 
chhlubpi.Username as LastUpdatedByUserName,
Policy_DTI_Exc = null, 
Policy_LTV_Exc = null,
Policy_SLTV_Exc = null,
Policy_FICO_Exc = null,
FC2.DTI_exc, FC2.LTV_exc, FC2.FICO_exc, 
case
	when ExceptionPricing1.FieldValue in ('True') or (ExceptionPricing1.FieldValue not in ('False') and ExceptionPricing1.FieldValue is not null) then 1
	when ExceptionPricing2.FieldValue in ('True') or (ExceptionPricing2.FieldValue not in ('False') and ExceptionPricing2.FieldValue is not null) then 1
	else 0
end as Pricing_exc,
FC2.Other_exc, 
FC2.Collateral_exc, 
FC2.Term_exc, 
FC2.Total_Exc_Cust, 
Total_Exc = null,
Exc_Count = null,
RptApp.SourceChannelID,
replace(replace(replace(channel.Name, char(10), ''), char(13), ''),',', '') as SourceChannelName,
case						
	when channel.Name like 'Private Bankers%' then 'Private Bank'						
	else 'Other'						
end as PrivateBank,
case when channel.code in ('2034') then 'Capital'
	 when channel.code in ('1078') then 'Piedmont'
	 when channel.code in ('2613') then 'Central Mountain'
	 else cci.Name 
End as District, 
channel.code, cci2.Name as ChannelType, a.CityName as ChannelCity,
AutoDec1status.autodecisionstatusname,
case when InternetApps.DeliveryMethodCD like 'I' then 'Yes'
	else 'No'
End as InternetApps,
chhd = null,
chhi = null,
chhppd = null,
PotentialDebt = null,
PIHeloc.FieldValue as PIHeloc,
isnull(Groot.EmployeeFlag,0) as EmployeeFlag,
null as Market_mgr

from View001 ad
	left join View007 chhcbpi ON ad.CreatedByPartyID = chhcbpi.PartyID
	left join View007 chhlubpi ON ad.LastUpdatedByPartyID = chhlubpi.PartyID
	left join 
	(select appid, appdetailid, decisionstatusname as autodecisionstatusname
	from View008										
	where appdetailsavepointid=2 and analystid = 3 and DecisionStatusName <> 'Review') as AutoDec1status ON ad.AppID = AutoDec1status.AppID and ad.AppDetailID = AutoDec1status.AppDetailID										


/*********** ver 2.0 - RS - 05.18.2018 ***********/
	Outer Apply
	(select ad1.AppID, ad1.AppDetailID, ad1.AppDetailSavePointID, ad1.loantypeid,
						case when AppStart.ApplicationStart >= ad1.CreationDate then AppStart.ApplicationStart
						else ad1.CreationDate
						End  as ApplicationStart
						from View001 ad1 left join
						View009 as AppDate ON ad1.AppID = AppDate.AppID
						Outer Apply (select case when AppDate.AppEntryCompletedDate is not null then AppDate.AppEntryCompletedDate 
									 when AppDate.AppEntryCompletedDate is null then AppDate.AppReceivedDate end as ApplicationStart
									 from View001 ad2 left join
									 View009 as AppDate ON ad2.AppID = AppDate.AppID
									 where ad2.AppDetailSavePointID = ad1.AppDetailSavePointID and ad1.AppID = ad2.AppID and ad1.AppDetailID = ad2.AppDetailID) AppStart
				  where ad.AppID = ad1.AppID and ad.AppDetailID = ad1.AppDetailID and ad.AppDetailSavePointID = ad1.AppDetailSavePointID) as AStart
                                                             
    left join View010 luads on (ad.AppDetailSavePointID = luads.AppDetailSavePointID)
    left join View011 p on ad.ProductID = p.ProductID
    
    left join View012 luct on (ad.CalculationTypeID = luct.ID)
    left join (View013 adlp
                inner join View014 lp on (adlp.LoanPurposeID = lp.LoanPurposeID)
               ) on (ad.AppID = adlp.AppID and
                     ad.AppDetailID = adlp.AppDetailID and
                     ad.AppDetailSavePointID = adlp.AppDetailSavePointID and
                     adlp.RankNum = 1)
    left join (select AppID, AppDetailID, AppDetailSavePointID, sum(isnull(RequestedAmount,0)) as sum_RequestedAmount
                from View015 adra
                group by AppID, AppDetailID, AppDetailSavePointID)
              AppDetailRequestedAmount_sum on (ad.AppID = AppDetailRequestedAmount_sum.AppID and
                                               ad.AppDetailID = AppDetailRequestedAmount_sum.AppDetailID and
                                               ad.AppDetailSavePointID = AppDetailRequestedAmount_sum.AppDetailSavePointID)
    left join (View016 AppDetailStatus_decision
                inner join View020 Status_decision on (AppDetailStatus_decision.StatusID = Status_decision.StatusID and
                                                          Status_decision.StatusTypeID = 2 /* Decision */)
               ) on (ad.AppID = AppDetailStatus_decision.AppID and
                     ad.AppDetailID = AppDetailStatus_decision.AppDetailID and
                     ad.AppDetailSavePointID = AppDetailStatus_decision.AppDetailSavePointID)
    left join (View017 AppDetailParty_analyst
                inner join View018 Person_analyst on (AppDetailParty_analyst.PartyID = Person_analyst.PartyID)
                inner join View007 usr on (Person_analyst.PartyID = usr.PartyID and
                                          Person_analyst.BeginDate = usr.BeginDate)
				inner join View019 as b ON AppDetailParty_analyst.PartyID = b.PartyID and b.IsActiveFL = 1
               ) on (ad.AppID = AppDetailParty_analyst.AppID and
                     ad.AppDetailID = AppDetailParty_analyst.AppDetailID and
                     ad.AppDetailSavePointID = AppDetailParty_analyst.AppDetailSavePointID and
                     AppDetailParty_analyst.AppPartyTypeID = 14 /* AppDetail Decisioned By User */)
    left join (View016 AppDetailStatus_workflow
                inner join View020 Status_workflow on (AppDetailStatus_workflow.StatusID = Status_workflow.StatusID and
                                                          Status_workflow.StatusTypeID = 1 /* Workflow */)
               ) on (ad.AppID = AppDetailStatus_workflow.AppID and
                     ad.AppDetailID = AppDetailStatus_workflow.AppDetailID and
                     ad.AppDetailSavePointID = AppDetailStatus_workflow.AppDetailSavePointID)
    left join (View016 AppDetailStatus_contractreview
                inner join View020 Status_contractreview on (AppDetailStatus_contractreview.StatusID = Status_contractreview.StatusID and
                                                                Status_contractreview.StatusTypeID = 21 /* Contract Review */)
                inner join View007 User_contractreviewlastupdated on (AppDetailStatus_contractreview.LastUpdatedByPartyID = User_contractreviewlastupdated.PartyID)
               ) on (ad.AppID = AppDetailStatus_contractreview.AppID and
                     ad.AppDetailID = AppDetailStatus_contractreview.AppDetailID and
                     ad.AppDetailSavePointID = AppDetailStatus_contractreview.AppDetailSavePointID)
    left join View021 lurr on (ad.RiskRatingID = lurr.ID)
	left join View022 FCA ON (ad.AppID = FCA.AppID and 
												 ad.AppDetailID = FCA.AppDetailID and 
												 FCA.fieldname = 'Approving Officer # (DLC)' and 
												 FCA.FieldValue is not null)
	left join View022 ExceptionPricing1																												
             ON (ad.AppID = ExceptionPricing1.AppID and
				 ad.AppDetailID = ExceptionPricing1.AppDetailID and
				 ExceptionPricing1.FieldName = '77-Pricing Exception (DLC)' and 
				 ExceptionPricing1.FieldValue in ('True'))																												
																												
	left join View022 ExceptionPricing2																												
             ON (ad.AppID = ExceptionPricing2.AppID and
				 ad.AppDetailID = ExceptionPricing2.AppDetailID and
				 ExceptionPricing2.FieldName = '77-Pricing Exception (DLC)' and
				 ExceptionPricing2.FieldValue not in ('True','False') and 
				 ExceptionPricing2.FieldValue is not null)

	left join 
	(select AppDetailID,
	sum(case when Fieldname = '71-D/I Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) as DTI_exc,				-- FieldID in (-653,-245,-244,-243,-242,-241)
	sum(case when Fieldname = '72-LTV Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) as LTV_exc,				-- FieldID in (-652,-250,-249,-248,-247,-246)
	sum(case when Fieldname = '73-FICO  Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) as FICO_exc,			-- FieldID in (-255,-254,-253,-252,-251)
	sum(case when FieldName = '77-Pricing Exception (DLC)' and FieldValue <> 'False' then 1 else 0 end) as Pricing_exc,		-- FieldID in (-682,-681,-680,-679,-678,-677,-650,-260,-259,-258,-257,-256)
	sum(case when FieldName = '79-Other Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) as Other_exc,			-- FieldID in (-649,-265,-264,-263,-262,-261)
	sum(case when FieldName = '75-Collateral Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) as Collateral_exc, -- FieldID in (-642,-641,-640,-639,-638,-637)
	sum(case when FieldName = '76-Term Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) as Term_exc,				-- FieldID in (-648,-647,-646,-645,-644,-643)
	sum(case when Fieldname = '71-D/I Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) +
	sum(case when Fieldname = '72-LTV Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) +
	sum(case when Fieldname = '73-FICO  Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) +
	sum(case when FieldName = '79-Other Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) +
	sum(case when FieldName = '75-Collateral Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) +
	sum(case when FieldName = '76-Term Exception (DLC)' and FieldValue = 'True' then 1 else 0 end) as Total_Exc_Cust
	from View022
	group by AppDetailID) FC2 ON (ad.AppDetailID = FC2.AppDetailID)


	left join (View023 RptApp
			  inner join View024 channel ON (RptApp.SourceChannelID = channel.PartyID and
													   channel.IsActiveFL = 1)
			  inner join View025 cc ON (channel.PartyID = cc.PartyID and 
																cc.ChannelClassificationItemID < 0)
			  inner join View026 cci ON (cc.ChannelClassificationItemID = cci.ChannelClassificationItemID)
			  left join View027 pcm ON (channel.PartyID = pcm.PartyID)
			  left join View028 cm ON (pcm.ContactMechanismID = cm.ContactMechanismID and 
														  cm.ContactMechanismTypeID = 6)  /* Address	*/
			  left join View029 a ON (cm.AddressID = a.AddressID)
			  inner join View025 cc2 ON (channel.PartyID = cc2.PartyID and 
																 cc2.ChannelClassificationItemID > 0)
			  inner join View026 cci2 ON (cc2.ChannelClassificationItemID = cci2.ChannelClassificationItemID and 
																	  cci2.ChannelClassificationItemID > 0))
		  	  ON (ad.AppID = RptApp.AppID)

	left join 
	(select AppID, Max(TotalScore) as TotalScore
	from View030
	where TypeID <> 0
	group by AppID) as FICO ON (ad.AppID = FICO.AppID)

	left join View009 InternetApps ON (ad.AppID = InternetApps.AppID)

	left join
	(select a.AppID, a.AppDetailID, b.FirstName as ServicingOfficerFirstName, b.LastName as ServicingOfficerLastName	
	 from View017 as a 
		left join View018 b ON (a.PartyID = b.PartyID and 
										 a.BeginDate = b.BeginDate)
		left join View031 c ON (a.AppPartyTypeID = c.AppPartyTypeID)
	 where a.AppPartyTypeID = 20 and 
		   a.Appdetailsavepointid = 0) Servicing ON (ad.Appid = Servicing.AppID and 
													 ad.AppDetailID = Servicing.AppDetailID)

	left join (select AppIndividual.AppID,
				case when Max(Convert(int,Person.IsEmployeeFL)) = 1 then 1
					 when Max(Convert(int,Person.IsEmployeeFL)) = 0 then null
				End as EmployeeFlag
				from View004 apapt
				inner join View032 Party on (apapt.PartyID = Party.PartyID)
				inner join View002 AppIndividual on (apapt.AppID = AppIndividual.AppID and
																		apapt.PartyID = AppIndividual.PartyID)
				inner join View031 apt on (apapt.AppPartyTypeID = apt.AppPartyTypeID)
				inner join View018 Person on (AppIndividual.PartyID = Person.PartyID and
														AppIndividual.BeginDate = Person.BeginDate)
				group by AppIndividual.AppID) as Groot ON (ad.AppID = Groot.AppID)

	left join View022 PIHeloc ON (ad.appid = PIHeloc.AppID and 
													 ad.AppDetailID = PIHeloc.AppDetailID and
													 PIHeloc.Fieldid in (-977,-890))

	left join View033 adcv ON (ad.appid = adcv.AppID and 
														  ad.AppDetailID = adcv.AppDetailID and
														  ad.AppDetailSavePointID = adcv.AppDetailSavePointID)
where ad.AppDetailSavePointID = 0 and 
	  ad.LoanTypeID = 1 and 
	  Status_decision.Name not in ('Cancelled')

OPTION (recompile);

  --Common Table Expression to identify total sum of authorized user monthly payments by AppID
WITH CTE_AUser (AppID, SumAUserMPayments) as
(	
	select h.AppID, Sum(h.MonthlyPayment) as SumAUserMPayments
	from 
		(select a.AppID, c.TradeID, c.DebtStatusCD, c.ECOACD, c.AccountNum, c.MonthlyPayment,  row_number() over (partition by a.AppID, c.AccountNum order by c.tradeid desc) as rownum
		 from View034 a 
		 inner join View035 b ON (a.PartyID = b.PartyID) 
		 inner join View036 c on (b.TradeID = c.TradeID)
		 where c.ECOACD in ('A') and 
			   c.DebtStatusCD in ('I') and 
			   c.IsOpenStatusFL = 1) h
	where h.rownum = 1
	group by h.AppID
),
  --Common Table Expression to identify individual product debt (AppDetailID) and partitioned Potential Debt (Grouped by AppID)
CTE_Debt (AppID, AppDetailID, chhppd, PotentialDebt) as
(
	SELECT
	t1.AppID,
	t1.AppDetailID,
	t1.chhppd,															
	SUM(t1.chhppd) OVER (Partition by t1.AppID ORDER BY t1.AppID, t1.AppDetailID) - case when AUser.SumAUserMPayments is null then 0 else AUser.SumAUserMPayments end as PotentialDebt									
	FROM (select ad.AppID, ad.AppDetailID, chhppd.chhppd
		  from View001 ad		
		  Outer Apply (select dbo.f_PotentialProductDebt(ad.AppID, ad.AppDetailID, ad.AppDetailSavePointID) as chhppd) chhppd
		  where ad.Appdetailsavepointid = 0 and 
				ad.loantypeid = 1) t1	
	left join CTE_AUser AUser ON (t1.AppID = AUser.AppID)
)
  -- Update Potential Product Debt Information for Individual Applications (AppDetailID)
update tr
	Set tr.chhppd = Debt.chhppd,
	tr.PotentialDebt = Debt.PotentialDebt
	from #Trending tr
	left join CTE_Debt Debt ON (tr.AppID = Debt.AppID and
								tr.AppDetailID = Debt.AppDetailID)

  --Common Table Expression to identify total Household debt grouped by AppID
;WITH CTE_chhd (AppID, CurrentHouseholdDebt) as
(
	select hha.AppID, sum(isnull(t.MonthlyPayment,0)) as CurrentHouseholdDebt
	from #HouseholdApplicants hha
	inner join View035 pt on (hha.PartyID = pt.PartyID and
											hha.BeginDate = pt.BeginDate)
	inner join View036 t on (pt.TradeID = t.TradeID and
									 t.DebtStatusCD in ('I','P','S'))
	group by hha.AppID
),
  --Common Table Expression to identify total Household Income grouped by AppID
CTE_chhi (AppID, Income) as
(
	select hha.AppID, sum(isnull(case IncomeFreqID
	when 99 then (convert(decimal(28,8),[pi].AmountPerPeriod) * 
				  convert(decimal(28,8),[pi].IncomeAdjustmentPct) *
				  convert(decimal(28,8),[pi].HoursPerWeek) * 
				  convert(decimal(28,8),52)) /
				  convert(decimal(28,8),12)
	else convert(decimal(28,8),[pi].AmountPerPeriod) *
		 convert(decimal(28,8),[pi].IncomeAdjustmentPct) *
		 convert(decimal(28,8),[pi].IncomeFreqID) / 
		 convert(decimal(28,8),12)
	end,0)) as Income
	from #HouseholdApplicants hha
		inner join View037 [pi] on (hha.PartyID = [pi].PartyID and
												  hha.BeginDate = [pi].BeginDate)
	where ([pi].IncomeStatusID <> 89 or [pi].IncomeStatusID is null) and
			not exists (select 1 from View040 e
						where e.RelationshipTypeID = 2 and
							  [pi].PartyID = e.ParentPartyID and
							  [pi].BeginDate = e.BeginDate and 
							  [pi].EmployerPartyID = e.ChildPartyID and
							  e.IsCurrentFL = 0)
	group by hha.AppID
)
  -- Update Household Income and Household Debt Information for Individual Applications
update tr										
	Set tr.chhd = isnull(chhd.CurrentHouseholdDebt, 0),
	tr.chhi = isnull(chhi.Income,0)
	from #Trending tr
	left join CTE_chhd chhd ON (tr.AppID = chhd.AppID)
	left join CTE_chhi chhi ON (tr.AppID = chhi.AppID);

/* 	ver 3.0 - RS - 12.21.2018  	*/
  -- Update CumulativeDTI, Policy Exceptions, and minimum FICO scores and the total number of Borrowers for each AppID in the Trending table variable.
update tr										
	Set tr.CumulativeDTI = 
	case when tr.chhi = 0 then 0																												
		 else (tr.chhd + tr.PotentialDebt) / tr.chhi																							
	end,
	tr.Policy_DTI_Exc = 
		case when tr.ApplicationStart < '20180101' then case											
			/************************************************************************************ Home Equity Products ************************************************************************************/										
			when tr.ProductID in (138,139,140,141,168,170,172,173) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO1 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO1 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO2 and  (case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO1 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				Else 0 End									
			/************************************************************************************ Automobile ************************************************************************************/										
			when tr.ProductID in (142,143) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO4 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO1 and @FICO5 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO1 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO2 and  (case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO1 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				Else 0 End									
			/************************************************************************************ Other Secured (1) ************************************************************************************/										
			when tr.ProductID in (133,145,146,147,148,158,161,162,166,167) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO4 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO1 and @FICO5 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO1 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI6 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO2 and  (case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO4 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO1 and @FICO5 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI6 then 1					
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				Else 0 End									
			/************************************************************************************ Other Personal Use Secured ************************************************************************************/										
			when tr.ProductID in (149) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO4 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO1 and @FICO5 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI7 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO1 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO2 and	(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO1 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
				Else 0 End									
			/************************************************************************************ Unsecured ************************************************************************************/										
			when tr.ProductID in (144,156,159,163,164) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO4 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO1 and @FICO5 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI7 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO1 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO2 and	(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO1 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO2 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
				Else 0 End 									
			Else 0 End										
		when tr.ApplicationStart > '20180101' then case                                          											
		/************************************************************************************ Home Equity Products ************************************************************************************/ 											
			when tr.ProductID in (138,139,140,141,168,170,173) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO6 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO7 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO6 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO7 and	(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO6 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI6 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO8 and @FICO7 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI1 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
			Else 0 End										
		/*********** rev 4.0 - RS - 05.22.2018 ***********/											
		/************************************************************************************ Bridge Loan Products ************************************************************************************/                                                                                                                                                                                   											
			when tr.ProductID in (172) and (tr.EmployeeFlag <> 1) then case										
				when tr.Totalscore >= @FICO6 and															(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1
				when tr.Totalscore between @FICO8 and @FICO7 and											(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1
			Else 0 End										
			/************************************************************************************ Automobile ************************************************************************************/										
			when tr.ProductID in (142,143) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO6 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO8 and @FICO7 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO8 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO9 and	(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO8 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
			Else 0 End										
			/************************************************************************************ Other Secured (1) ************************************************************************************/										
			when tr.ProductID in (133,145,146,147,148,158,161,162,166,167) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO6 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO8 and @FICO7 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO8 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI6 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO9 and	(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO6 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI4 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO8 and @FICO7 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI6 then 1					
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1		
			Else 0 End										
			/************************************************************************************ Other Personal Use Secured ************************************************************************************/										
			when tr.ProductID in (149) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO6 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO8 and @FICO7 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI7 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO8 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO9 and	(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO8 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
			Else 0 End										
			/************************************************************************************ Unsecured ************************************************************************************/										
			when tr.ProductID in (144,156,159,163,164) and (tr.EmployeeFlag <> 1) then case										
				when tr.chhi <= @income1 and tr.Totalscore >= @FICO6 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1		
				when tr.chhi <= @income1 and tr.Totalscore between @FICO8 and @FICO7 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1					
				when tr.chhi <= @income1 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI7 then 1					
				when tr.chhi <= @income1 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
				when tr.chhi between @income2 and @income3 and tr.Totalscore >= @FICO8 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi between @income2 and @income3 and tr.Totalscore between @FICO3 and @FICO9 and	(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI3 then 1									
				when tr.chhi between @income2 and @income3 and tr.Totalscore < @FICO3 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1					
				when tr.chhi >= @income4 and tr.Totalscore >= @FICO8 and									(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI5 then 1		
				when tr.chhi >= @income4 and tr.Totalscore between @FICO3 and @FICO9 and					(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI2 then 1					
				when tr.chhi >= @income4 and tr.Totalscore < @FICO3 and										(case when tr.chhi = 0 then 0 else (tr.chhd + tr.PotentialDebt) / tr.chhi end) > @DTI8 then 1		
			Else 0 End
		Else 0 End
	Else 0 End,
	Policy_LTV_Exc = 
	case
		when tr.LoanToValue > @LTV1 and tr.ProductID in (138,139,141,168,170,173) then 1
		when tr.LoanToValue > @LTV2 and tr.ProductID in (172) then 1 /*********** rev 4.0 - RS - 05.22.2018 ***********/
		when tr.LoanToValue > @LTV3 and tr.ProductID in (140) then 1
		when tr.LoanToValue > @LTV4 and tr.ProductID in (142,143) then 1
		when tr.LoanToValue > @LTV5 and tr.ProductID in (149) then 1
		else 0
    end, 
	Policy_SLTV_Exc = case when tr.LoanToValue > @LTV6 and tr.ProductID in (138,139,140,141,168,170,172,173) then 1 else 0 end,
	Policy_FICO_Exc = case when tr.DecisionStatusName in ('Approved','Aprvd. Rejected by Applicant','Counteroffer','Counteroffer Rejected by Applicant') and tr.DecisionStatusDate < '20170823' then                                                                                                                                                                                  
			 (case when tr.TotalScore < @FICO3 then 1                                                                                                                                                                        
			  when MiniF.MaxBorrowers = 1 and MiniF.Min_FICO is null and tr.DecisionStatusName in ('Approved','Aprvd. Rejected by Applicant','Counteroffer','Counteroffer Rejected by Applicant') then 1 else 0 End)                                                                                                                                                                         
         when tr.DecisionStatusName in ('Approved','Aprvd. Rejected by Applicant','Counteroffer','Counteroffer Rejected by Applicant') and tr.DecisionStatusDate > '20170823' then                                                                                                                                                                                  
             (case when tr.TotalScore < 640 then 1
              when tr.TotalScore < @FICO8 and tr.ProductID in (172) then 1 /*********** rev 4.0 - RS - 05.22.2018 ***********/
              when MiniF.MaxBorrowers = 1 and MiniF.Min_FICO is null and tr.DecisionStatusName in ('Approved','Aprvd. Rejected by Applicant','Counteroffer','Counteroffer Rejected by Applicant') then 1                                                                                                                                                                           
              when MiniF.Min_FICO < @FICO8 and tr.DecisionStatusName in ('Approved','Aprvd. Rejected by Applicant','Counteroffer','Counteroffer Rejected by Applicant') and (tr.ProductID in (139) or (tr.ProductID in (170) and tr.PIHeloc in ('Interest Only'))) then 1                                                                                                                                                                       
              else 0 End)                                                                                                                                                                         
       else 0                                                                                                                                                                              
       end
	from #Trending tr
	left join  (select ad.AppID, 
				ad.AppDetailID,
				AppIndividual.PartyID,
				apt.Name as AssociationName,
				Goku.Min_FICO,
				Count(party.PartyID) Over (Partition By ad.AppID) as MaxBorrowers

				from View001 ad
				left join (View004 apapt
						   inner join View032 Party on (apapt.PartyID = Party.PartyID)
						   inner join View002 AppIndividual on (apapt.AppID = AppIndividual.AppID and
																				apapt.PartyID = AppIndividual.PartyID)
						   inner join View031 apt on (apapt.AppPartyTypeID = apt.AppPartyTypeID)
						   inner join View018 Person on (AppIndividual.PartyID = Person.PartyID and
																  AppIndividual.BeginDate = Person.BeginDate)
						  ) ON (ad.AppID = apapt.AppID)
				left join (select distinct aps.AppID,
						   Min(Score.TotalScore) over (Partition By aps.AppID) as Min_FICO
						   from View038 aps
						   inner join View039 as Score ON (aps.ScoreID = Score.ScoreID and
																   Score.ScoreTypeID in (51,108,1016))
						  ) Goku ON (ad.AppID = Goku.AppID)
				where ad.AppDetailSavePointID = 0 and
					  ad.loantypeid = 1 and 
					  apt.Name not in ('Withdrawn','Co-Signer')) MiniF 
				ON (tr.AppID = MiniF.AppID and
					tr.AppDetailID = MiniF.AppDetailID);

  -- Update Potential Product DTI, Potential PaymentToIncome, Total number of Exceptions, Exception counts broken over 1, 2, >2, and DTI band for Individual Applications
update tr
	Set tr.PotentialProductDebtToIncome =
		case when tr.chhi = 0 then 0 
			 else (convert(decimal(28,8),tr.chhd) + convert(decimal(28,8),tr.chhppd)) / convert(decimal(28,8),tr.chhi) 
		End,
	tr.PotentialPaymentToIncome = 
		case when tr.chhi = 0 then 0
			 else convert(decimal(28,8),tr.chhppd) / convert(decimal(28,8),tr.chhi)
		End,
	tr.Total_Exc = tr.Policy_DTI_Exc + tr.Policy_LTV_Exc + tr.Policy_FICO_Exc + tr.Other_exc + tr.Collateral_exc + tr.Term_exc,
	tr.Exc_Count = isnull(
		case when tr.Policy_DTI_Exc + tr.Policy_LTV_Exc + tr.Policy_FICO_Exc + tr.Other_exc + tr.Collateral_exc + tr.Term_exc = 1 then '1'
			 when tr.Policy_DTI_Exc + tr.Policy_LTV_Exc + tr.Policy_FICO_Exc + tr.Other_exc + tr.Collateral_exc + tr.Term_exc = 2 then '2'
			 when tr.Policy_DTI_Exc + tr.Policy_LTV_Exc + tr.Policy_FICO_Exc + tr.Other_exc + tr.Collateral_exc + tr.Term_exc > 2 then '3+'
		end,0),
	tr.DTI_Band = 
		case when (tr.CumulativeDTI) <= 0 then '0%'				
			 when (tr.CumulativeDTI) > 0 AND (tr.CumulativeDTI) <= @DTI7 then '0.1%-35.0%'				
			 when (tr.CumulativeDTI) between @DTI70 and 0.429 then '35.0% - 42.9%'				
			 when (tr.CumulativeDTI) >= @DTI1 then 'Over 43.0%'							
		end,
	tr.HomeEquityLL = 
		case when tr.ProductGrouping in ('Auto','Unsecured Term','Other Secured') then 'Other Direct Installment'
			 when tr.ProductGrouping in ('Unsecured LOC','Credit Card') then 'Other Credit Lines'
			 when tr.ProductGrouping in ('HEIL','Bridge Loan') then 'Home Equity Installment'
			 when tr.ProductGrouping in ('HELOC') then 'Home Equity Lines of Credit'
		end,
	tr.LoansLines = 
		case when tr.ProductGrouping in ('Auto','Unsecured Term','Other Secured','HEIL','Bridge Loan') then 'Term Loan'
			 when tr.ProductGrouping in ('Unsecured LOC','Credit Card','HELOC') then 'Line of Credit'
		end
	from #Trending tr;

select *
from #Trending

Drop Table #HouseholdApplicants
Drop Table #Trending

SET STATISTICS TIME OFF;
