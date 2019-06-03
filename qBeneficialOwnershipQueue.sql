
/******************************************************************************************************************************
	*Disclaimer: The following sql script is not in production has been significantly modified from the original version so as to preserve the integrity of the original table, view, alias, and column names.

    Author:   RS
    Date:     07.12.2018
    Template: Yadkin SBLC Beneficial Ownership Loans 
    Purpose:  Return every SBLC application where EITHER 
		-	AppDate after 4/1/18
		-	Contains FieldValue of Beneficial Ownership custom field (custom field value of -1030)
		-	All loans that spent any time in the B: Yadkin Quick Loans queue (-228 queue id)
		-	Contains whether an amendment generated or not (document id -79)
		-	Current decisionstatus
		-	WHERE CreatedDate >= 4/1/18 and any time spent in the B: Yadkin Quick Loans queue


                                                      Version History

    rev 1.0 - RS - 07.12.2018  -  Original Version Created.
    rev 2.0 - RS - 07.25.2018  -  Added loans with additional criteria: a. Loans with a loan amount > 100k
																		b. Pulled in an additional column from the flatcustomfields table -307
    rev 3.0 - RS - 07.31.2018  -  Added loans that had a requested amount > $100k along with the following additional columns:
									- TradeName
									- CompanyOwnershipTypeName
									- District
									- One of two Stips: stipulation ID = 54 or 103
    rev 4.0 - RS - 08.01.2018  -  Added 3 more columns: Loan Officer Name, BDO Name, WorkflowStatusName

******************************************************************************************************************************/ 


Set Transaction Isolation Level Read Uncommitted
SET STATISTICS TIME ON;

select 
aa.AppID, 
aa.AppDetailID, 
AStart.ApplicationStart as AppDate, 
Company.TradeName,
LuCoOwnType.Name as CompanyOwnershipTypeName,
Amendment.CompletedDate Amendment_CompletedDate,
Status_decision.LastUpdateDate as DecisionStatusDate, 
Status_decision.Name as DecisionStatusName,
case when p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') and PIHeloc.FieldValue in ('Interest Only') then 'Int Only HELOC'
	 when AStart.ApplicationStart > '2017-08-23' and p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') and PIHeloc.FieldValue is null then 'Int Only HELOC'
	 when p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') and PIHeloc.FieldValue in ('Principal and Interest') then 'P & I HELOC'
	 when p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') then 'Lock Option HELOC'
Else p.ShortName 
End as ProductShortName,
AppDetailRequestedAmount_sum.sum_RequestedAmount as AmountRequested,
fcfpaynet.FieldValue as Paynet,
Servicing.ServicingOfficerFirstName + ' ' + Servicing.ServicingOfficerLastName as ServicingOfficer,
fcf.fieldvalue as ProcessorName,
fcfbenefown.fieldvalue as BeneficalOwnershipFormQuestion,
Queu.Name as CurrentQueue,
channel.district,
case when stipAppr.stipnum > 0 then 'Open'
else 'Satisfied' End as Stips54_103,
fcfBDO.Fieldvalue as BDO,
fcfOfficer.Fieldvalue as LoanOfficer,
Status_workflow.Name as WorkFlowStatusName,
aa.AccountNumber

from View001 as aa 
       
left join  (select a.AppID, 
			a.AppDetailID, 
			b.FirstName as ServicingOfficerFirstName, 
			b.LastName as ServicingOfficerLastName 
			from View002 as a 
			left join View003 as b ON (a.PartyID = b.PartyID)
			left join View004 as c ON (a.AppPartyTypeID = c.AppPartyTypeID)
			where a.AppPartyTypeID = 20 and 
				  a.Appdetailsavepointid = 0
		   ) as Servicing ON (aa.appid = Servicing.AppID and 
							  aa.AppDetailID = Servicing.AppDetailID)

left join View005 p on (aa.ProductID = p.ProductID)
inner join (select AppID, 
			AppDetailID, 
			AppDetailSavePointID, 
			Name, 
			ADS.LastUpdateDate, 
			case when Name in ('Aprvd. Rejected by Applicant','Counteroffer Rejected by Applicant') then DATEADD(day,-45, ADS.LastUpdateDate) 
				 else ADS.LastUpdateDate 
			End as DecisionStatusDatev2,
			LEFT(DATENAME(MONTH, case when Name in ('Aprvd. Rejected by Applicant','Counteroffer Rejected by Applicant') then DATEADD(day,-45, ADS.LastUpdateDate) 
									  else ADS.LastUpdateDate 
								 End
						 ), 3
				) 
			+ ' ' + 
			CAST(YEAR(case when Name in ('Aprvd. Rejected by Applicant','Counteroffer Rejected by Applicant') then DATEADD(day,-45, ADS.LastUpdateDate) 
							else ADS.LastUpdateDate 
						End
					 ) AS VARCHAR
				) as DecisionMonth 
			from View006 ADS
            inner join View007 Status_dec on (ADS.StatusID = Status_dec.StatusID and
											  Status_dec.StatusTypeID = 2 /* Decision */) 
			) Status_decision on (aa.AppID = Status_decision.AppID and
								  aa.AppDetailID = Status_decision.AppDetailID and
								  aa.AppDetailSavePointID = Status_decision.AppDetailSavePointID) 

left join  (select dr.AppID, 
			dr.AppDetailID, 
			dr.DocumentRequestID, 
			dr.DocumentID, 
			dr.CreationDate, 
			dr.CompletedDate
			from View008 dr 
			where dr.DocumentID in (-79) and 
				  dr.AppDetailSavePointID = 0 and 
				  dr.CompletedDate = (select max(dr1.CompletedDate) as CompletedDate
				  from View008 dr1
				  where dr.AppID = dr1.AppID and 
					    dr.AppDetailID = dr1.AppDetailID and 
					    dr.AppDetailSavePointID = dr1.AppDetailSavePointID and 
					    dr.DocumentID = dr1.DocumentID)
			) Amendment ON (aa.AppID = Amendment.AppID and 
							aa.AppDetailID = Amendment.AppDetailID)

left join  (select ad.AppID, 
			ad.AppDetailID, 
			ad.AppDetailSavePointID, 
			ad.loantypeid,
			case when AppStart.ApplicationStart >= ad.CreationDate then AppStart.ApplicationStart
				 else ad.CreationDate
			End as ApplicationStart
			from View001 ad 
			left join View009 AppDate ON (ad.AppID = AppDate.AppID)
			Outer Apply (select case when AppDate.AppEntryCompletedDate is not null then AppDate.AppEntryCompletedDate 
									when AppDate.AppEntryCompletedDate is null then AppDate.AppReceivedDate 
								End as ApplicationStart
						 from View001 ad2 
						 left join View009 AppDate ON (ad2.AppID = AppDate.AppID)
						 where ad2.AppDetailSavePointID = 0 and 
							   ad.AppID = ad2.AppID and 
							   ad.AppDetailID = ad2.AppDetailID
						) AppStart
			where ad.AppDetailSavePointID = 0
			) AStart ON (aa.AppID = AStart.AppID and 
						 aa.AppDetailID = AStart.AppDetailID and 
						 aa.AppDetailSavePointID = AStart.AppDetailSavePointID)

left join (select AppID, AppDetailID, FieldValue
            from View010
            where Fieldid in (-977,-890)
		  ) PIHeloc ON (aa.appid = PIHeloc.AppID and 
						aa.AppDetailID = PIHeloc.AppDetailID)

left join (select adq.AppID, adq.AppDetailID, adq.ID, que.Name
			from View011 adq 
			inner join View012 que ON (adq.QueueID = que.ID)
			where IsCurrentInQueueFL = 1
		  ) Queu ON (aa.AppID = Queu.AppID and 
					 aa.AppDetailID = Queu.AppDetailID)

outer apply (select Count(*) as YadkinCount
			from View011 adq 
			inner join View012 que ON (adq.QueueID = que.ID)
			where adq.QueueID in (-228) and
				  aa.AppID = adq.AppID and 
				  aa.AppDetailID = adq.AppDetailID
		    ) Yadkin

Outer Apply (select an.AppID, 
			an.LastUpdateDate, 
			an.NoteEntry
			from View013 an
			where aa.AppID = an.AppID
			order by an.LastUpdateDate desc
			offset 0 rows fetch next 1 rows only
			) v2

outer apply (select fcf.FieldValue
			 from View010 fcf
			 where fcf.fieldid in (-38) and 
				  aa.AppID = fcf.AppID and 
				  aa.AppDetailID = fcf.AppDetailID
			) fcf

outer apply (select fcf.FieldValue
			 from View010 fcf
			 where fcf.fieldid in (-1030) and 
				  aa.AppID = fcf.AppID and 
				  aa.AppDetailID = fcf.AppDetailID
			) fcfbenefown

outer apply (select fcf.FieldValue
			 from View010 fcf
			 where fcf.FieldID IN (- 798) and 
				  aa.AppID = fcf.AppID and 
				  aa.AppDetailID = fcf.AppDetailID
			) fcfpaynet

	   left join (select AppID, AppDetailID, AppDetailSavePointID, sum(isnull(RequestedAmount,0)) as sum_RequestedAmount
				  from View014 adra
                  group by AppID, AppDetailID, AppDetailSavePointID)
                  AppDetailRequestedAmount_sum on (aa.AppID = AppDetailRequestedAmount_sum.AppID and
												   aa.AppDetailID = AppDetailRequestedAmount_sum.AppDetailID and
												   aa.AppDetailSavePointID = AppDetailRequestedAmount_sum.AppDetailSavePointID)

/*********** rev 3.0 - RS - 07.31.2018 ***********/
	left join (View015 apapt
			   inner join View016 AppCompany on (apapt.AppID = AppCompany.AppID and
															  apapt.PartyID = AppCompany.PartyID)
			   inner join View017 Company on (AppCompany.PartyID = Company.PartyID and
														AppCompany.BeginDate = Company.BeginDate)
			   inner join View004 apt on (apapt.AppPartyTypeID = apt.AppPartyTypeID and
														 apt.IsApplicantPartyTypeFL = 1 and
														 apapt.AppPartyTypeID = 1)
			  ) on (aa.AppID = apapt.AppID)
    left join View018 LuCoOwnType on (Company.CompanyOwnershipTypeID = LuCoOwnType.ID)
	left join View019 RptApp ON (aa.AppID = RptApp.AppID)
	left join View020 channel ON (RptApp.SourceChannelID = channel.SourceChannelID)

	outer apply (select count(*) as stipNum
				 from View021 ads
				 INNER JOIN View007 st ON (ads.StatusID = st.StatusID)
				 where ads.AppDetailsavepointid = aa.AppDetailsavepointid and 
				       ads.AppDetailID = aa.AppDetailID and 
					   ads.AppID = aa.AppID and 
					   ads.StipulationID in (54,103) and
					   st.Name in ('Open')
				) stipAppr

	left join View010 fcfBDO ON (aa.appid = fcfBDO.AppID and 
													aa.AppDetailID = fcfBDO.AppDetailID and 
													fcfBDO.Fieldid in (-11))

	left join View010 fcfOfficer ON (aa.appid = fcfOfficer.AppID and 
														aa.AppDetailID = fcfOfficer.AppDetailID and 
														fcfOfficer.Fieldid in (-15))

    left join (View006 AppDetailStatus_workflow
               inner join View007 Status_workflow on (AppDetailStatus_workflow.StatusID = Status_workflow.StatusID and
															   Status_workflow.StatusTypeID = 1 /* Workflow */)
              ) on (aa.AppID = AppDetailStatus_workflow.AppID and
                    aa.AppDetailID = AppDetailStatus_workflow.AppDetailID and
                    aa.AppDetailSavePointID = AppDetailStatus_workflow.AppDetailSavePointID)

where aa.AppDetailSavePointID = 0 and 
	  aa.loantypeid = 2 and 
	  AStart.ApplicationStart >= '2018-04-01' and
	  (Yadkin.YadkinCount > 0 OR
	  AppDetailRequestedAmount_sum.sum_RequestedAmount > 100000)


order by ServicingOfficer

OPTION (recompile)
SET STATISTICS TIME OFF