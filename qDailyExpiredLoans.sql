
/******************************************************************************************************************************
	*Disclaimer: The following sql script is not in production has been significantly modified from the original version so as to preserve the integrity of the original table, view, alias, and column names.

    Author:   RS
    Date:     05.15.2018
    Template: Daily Expired Loans Report (UnderWriter)
    Purpose:  Return every consumer application where EITHER 1. No Decline letter was sent for when application was placed into Decline status >= 7 calendar days, or
															 2. No NOI letter was sent for applications in the Incomplete status > 1 calendar day, or
															 3. an RE application remaining in the Review status >=25 days from decision status date, or
															 4. an non-RE application remaining in the Review status >=5 days from decision status date.

                                                      Version History

    rev 1.0 - RS - 05.15.2018  -  Original Version Created.
    rev 2.0 - RS - 05.17.2018  -  Added a LastAppNoteDate column to show the date that the most recent note was appended to the application’s note history.
    rev 3.0 - RS - 05.18.2018  -  Updated the code that evaluates the Application date on the AppDetailID level to point to the CreationDate column
								  of the View001 table.
    rev 4.0 - RS - 05.21.2018  -  Added filtering restrictions for RE products in review status >= 25 days and non-RE products in review status >= 10 days.
    rev 5.0 - RS - 05.23.2018  -  Added current queue column.
    rev 6.0 - RS - 05.23.2018  -  Removed applications in the 'C: Pending Reports' queue, and changed from 10 to 5 days from decisionstatusdate for applications in review status.
    rev 7.0 - RS - 05.24.2018  -  Added in Processor name and actual last note contents columns.
    rev 8.0 - RS - 06.14.2018  -  Removed applictions in the 'C: Followup' queue.
    rev 9.0 - RS - 06.19.2018  -  Added applications in a "Review" status with an application submitted date >= 70 days from report runtime date.
******************************************************************************************************************************/ 

Set Transaction Isolation Level Read Uncommitted
SET STATISTICS TIME ON;

select ad.AppID, ad.AppDetailID, AStart.ApplicationStart as AppDate, Status_decision.LastUpdateDate as DecisionStatusDate, Status_decision.Name as DecisionStatusName,
case when p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') and PIHeloc.FieldValue in ('Interest Only') then 'Int Only HELOC'
when AStart.ApplicationStart > '2017-08-23' and p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') and PIHeloc.FieldValue is null then 'Int Only HELOC'
when p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') and PIHeloc.FieldValue in ('Principal and Interest') then 'P & I HELOC'
when p.ShortName in ('Lock Option HELOC','Lock Option HELOC 17') then 'Lock Option HELOC'
Else p.ShortName End as ProductShortName,
Servicing.ServicingOfficerFirstName + ' ' + Servicing.ServicingOfficerLastName as ServicingOfficer, 
/*********** rev 7.0 - RS - 05.24.2018 ***********/
fcf.fieldvalue as ProcessorName,
DATEDIFF(Day,Status_decision.LastUpdateDate, GETUTCDATE())  as Time_in_Status,
Case
	 When (DATEDIFF(Day,Status_decision.LastUpdateDate, GETUTCDATE())) < 25 Then '< 25 days'
	 When (DATEDIFF(Day,Status_decision.LastUpdateDate, GETUTCDATE())) >= 25 Then '>= 25 days'
End as Time_in_Status_Band,
/*********** rev 5.0 - RS - 05.23.2018 ***********/
Queu.Name as CurrentQueue,
/*********** rev 2.0 - RS - 05.17.2018 ***********/
v2.LastUpdateDate as LastAppNoteDate,
replace(replace(replace(v2.NoteEntry, char(10), ''), char(13), ''), char(44), '') as LastNoteEntry

from View001 as ad 
       
       left join (select a.AppID, a.AppDetailID, b.FirstName as ServicingOfficerFirstName, b.LastName as ServicingOfficerLastName 
				  from View002 as a 
				  left join View003 as b ON (a.PartyID = b.PartyID)
				  left join View004 as c ON (a.AppPartyTypeID = c.AppPartyTypeID)
				  where a.AppPartyTypeID = 20 and 
						a.Appdetailsavepointid = 0
				  ) Servicing ON (ad.appid = Servicing.AppID and 
								  ad.AppDetailID = Servicing.AppDetailID)
	   left join View005 p on ad.ProductID = p.ProductID
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
										End),3) + ' ' + 
				   CAST(YEAR(case when Name in ('Aprvd. Rejected by Applicant','Counteroffer Rejected by Applicant') then DATEADD(day,-45, ADS.LastUpdateDate) 
								  else ADS.LastUpdateDate 
							 End) AS VARCHAR) as DecisionMonth 
				   from View006 ADS
                   inner join View007 Status_dec on (ADS.StatusID = Status_dec.StatusID and
															 Status_dec.StatusTypeID = 2 /* Decision */) 
				  ) Status_decision on (ad.AppID = Status_decision.AppID and
										ad.AppDetailID = Status_decision.AppDetailID and
										ad.AppDetailSavePointID = Status_decision.AppDetailSavePointID)
       left join (select dr.AppID, 
				  dr.AppDetailID, 
				  dr.DocumentRequestID, 
				  dr.DocumentID, 
				  dr.CreationDate, 
				  dr.CompletedDate
				  from View008 dr 
				  where dr.DocumentID in (-23) and 
						dr.AppDetailSavePointID = 0 and 
						dr.CompletedDate = (select max(dr1.CompletedDate) as CompletedDate
											from View008 dr1
											where dr.AppID = dr1.AppID and 
												  dr.AppDetailID = dr1.AppDetailID and 
												  dr.AppDetailSavePointID = dr1.AppDetailSavePointID and 
												  dr.DocumentID = dr1.DocumentID)
				 ) NOIComplete ON (ad.AppID = NOIComplete.AppID and 
								   ad.AppDetailID = NOIComplete.AppDetailID)
       left join (select dr.AppID, 
				  dr.AppDetailID, 
				  dr.DocumentRequestID, 
				  dr.DocumentID, 
				  dr.CreationDate, 
				  dr.CompletedDate
				  from View008 dr 
				  where dr.DocumentID in (-24) and 
						dr.AppDetailSavePointID = 0 and 
						dr.CompletedDate = (select max(dr1.CompletedDate) as CompletedDate
											from View008 dr1
											where dr.AppID = dr1.AppID and 
												  dr.AppDetailID = dr1.AppDetailID and 
												  dr.AppDetailSavePointID = dr1.AppDetailSavePointID and 
												  dr.DocumentID = dr1.DocumentID)
				 ) DeclineComplete ON (ad.AppID = DeclineComplete.AppID and 
									   ad.AppDetailID = DeclineComplete.AppDetailID)
       left join (select dr.AppID, 
				  dr.AppDetailID, 
				  dr.DocumentRequestID, 
				  dr.DocumentID, 
				  dr.CreationDate, 
				  dr.CompletedDate
				  from View008 dr 
				  where dr.DocumentID in (-57) and 
						dr.AppDetailSavePointID = 0 and 
						dr.CompletedDate = (select max(dr1.CompletedDate) as CompletedDate
											from View008 dr1
											where dr.AppID = dr1.AppID and 
												  dr.AppDetailID = dr1.AppDetailID and 
												  dr.AppDetailSavePointID = dr1.AppDetailSavePointID and 
												  dr.DocumentID = dr1.DocumentID)
				 ) CCardComplete ON (ad.AppID = CCardComplete.AppID and 
									 ad.AppDetailID = CCardComplete.AppDetailID)

/*********** rev 3.0 - RS - 05.18.2018 ***********/
       left join (select ad.AppID, ad.AppDetailID, ad.AppDetailSavePointID, ad.loantypeid,
						case when AppStart.ApplicationStart >= ad.CreationDate then AppStart.ApplicationStart
						else ad.CreationDate
						End  as ApplicationStart
						from View001 ad left join
						View009 as AppDate ON ad.AppID = AppDate.AppID
						Outer Apply (select case when AppDate.AppEntryCompletedDate is not null then AppDate.AppEntryCompletedDate 
									 when AppDate.AppEntryCompletedDate is null then AppDate.AppReceivedDate end as ApplicationStart
									 from View001 ad2 left join
									 View009 as AppDate ON ad2.AppID = AppDate.AppID
									 where ad2.AppDetailSavePointID = 0 and ad.AppID = ad2.AppID and ad.AppDetailID = ad2.AppDetailID) AppStart
				  where ad.AppDetailSavePointID = 0) as AStart ON ad.AppID = AStart.AppID and ad.AppDetailID = AStart.AppDetailID and ad.AppDetailSavePointID = AStart.AppDetailSavePointID

       left join (select AppID, AppDetailID, FieldValue
                  from View010
                  where Fieldid in (-977,-890)
				 ) PIHeloc ON (ad.appid = PIHeloc.AppID and 
							   ad.AppDetailID = PIHeloc.AppDetailID)

/*********** rev 2.0 - RS - 05.17.2018 ***********/
	   Outer Apply (select an.AppID, an.LastUpdateDate, an.NoteEntry
				    from View011 an
				    where ad.AppID = an.AppID
				    order by an.LastUpdateDate desc
				    offset 0 rows fetch next 1 rows only) v2

/*********** rev 5.0 - RS - 05.23.2018 ***********/
	   left join (select adq.AppID, adq.AppDetailID, adq.ID, que.Name
				  from  View012 adq 
				  inner join View013 que ON (adq.QueueID = que.ID)
				  where IsCurrentInQueueFL = 1
				 ) Queu ON (ad.AppID = Queu.AppID and 
							ad.AppDetailID = Queu.AppDetailID)

/*********** rev 7.0 - RS - 05.24.2018 ***********/
	   outer apply (select fcf.FieldValue
					from View010 fcf
					where fcf.fieldid in (-475, -490, -486, -488, -480, -492) and 
						  ad.AppID = fcf.AppID and 
						  ad.AppDetailID = fcf.AppDetailID) fcf

/*********** rev 8.0 - RS - 05.24.2018 ***********/
where ad.AppDetailSavePointID = 0 and 
	  ad.loantypeid = 1 and 
	  p.ShortName not in ('TDR') and 
	  Year(AStart.ApplicationStart) in (year(GETUTCDATE()), year(GETUTCDATE())-1) and 
	  (LEFT(Queu.Name, 18) not in ('C: Pending Reports') and LEFT(Queu.Name, 11) not in ('C: Followup')) and
	  ( (Status_decision.Name in ('Declined') and DeclineComplete.CompletedDate is null and Status_decision.LastUpdateDate <= DATEADD(DAY, -7, GETUTCDATE())
		) or
		(Status_decision.Name in ('Incomplete') and NOIComplete.CompletedDate is null and CCardComplete.CompletedDate is null and Status_decision.LastUpdateDate < DATEADD(DAY, -1, GETUTCDATE())
		) or

/*********** rev 4.0 - RS - 05.21.2018 ***********/
		(Status_decision.Name in ('Review') and 
		 Status_decision.LastUpdateDate <= DATEADD(DAY, -25, GETUTCDATE()) and 
		 p.ProductID in (138,139,140,141,168,170,172)
		) or

	    (Status_decision.Name in ('Review') and 
		 AStart.ApplicationStart <= DATEADD(DAY, -70, GETUTCDATE()) and 
		 p.ProductID in (138,139,140,141,168,170,172)
	    ) or

	    (Status_decision.Name in ('Review') and 
		 Status_decision.LastUpdateDate <= DATEADD(DAY, -5, GETUTCDATE()) and 
		 p.ProductID not in (138,139,140,141,168,170,172)
		)
	  )

order by ServicingOfficer

OPTION (recompile)
SET STATISTICS TIME OFF
