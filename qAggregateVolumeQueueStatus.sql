
/******************************************************************************************************************************
	*Disclaimer: The following sql script is not in production has been significantly modified from the original version so as to preserve the integrity of the original table, view, alias, and column names.

	Author(s) / Editor(s):   RS
	Date:     02.21.2018
	Template: Queue Status
	Purpose:  Returns the volume for each bucket from Consumer / Small Business products in each of the respective queues.
			  Evaluation of time spent in queue is calculated by subtracting number of non-business days (NBD) from the total amount of days between the start and end date.

                                                      Version History

    ver 1.0 - RS - 02.21.2018  -  Updated Version Created.
    ver 2.0 - RS - 11.28.2018  -  Added 2 new columns that sum up the total number of consumer and SBLC applications that were submitted the previous business day.
******************************************************************************************************************************/ 
 
Set Transaction Isolation Level Read Uncommitted
Set NOCOUNT ON
Set Statistics Time On

Declare @StartDate DateTime = DATEADD(MONTH,-2,SYSUTCDATETIME())
Declare @EndDate DateTime = SYSUTCDATETIME()
Declare @BusinessDaysP Int

 Declare @QueueTimes Table
(AppID Int,
 AppDetailID Int,
 Name VarChar(Max),
 QueueID Int,
 AppDetailSavePointID Int,
 ProductID Int,
 ProductShortName VarChar(30),
 DecisionStatusName VarChar(30),
 IsCurrentInQueueFL Int,
 CreationDate DateTime,
 AppMonth Int,
 AppYear Int,
 LoantypeID Int,
 DecisionStatusID Int,
 QueueEntryDate DateTime,
 QueueEntryDay Date,
 CalendarDays DECIMAL(7),
 present date,
 QueueEntry_PresentDateNBD Int,
 NBDPresent Int)

Declare @Aggregates Table
([Date] DateTime, 
 [DLC RE Secured] Int,
 [DLC Quick Loans/ CC] Int,
 [DLC Total Apps] Int,
 [DLC Oldest App] Date,	
 [DLC Oldest in Queue] Int,
 [SBLC RE Secured] Int,
 [SBLC Non_RE] Int,
 [SBLC Total Apps] Int,
 [SBLC Oldest App] Date,
 [SBLC Oldest in Queue] Int,
 [DLC Total Apps Previous Day] Int,
 [SBLC Total Apps Previous Day] Int,
 [Previous Business Day] nvarchar(50))

INSERT INTO @Aggregates ([Date], [DLC RE Secured], [DLC Quick Loans/ CC], [DLC Total Apps], [DLC Oldest App], [DLC Oldest in Queue], [SBLC RE Secured], [SBLC Non_RE], [SBLC Total Apps], [SBLC Oldest App], [SBLC Oldest in Queue])
VALUES (null, null, null, null, null, null, null, null, null, null, null)

Declare @NonBusinessDates Table 
(NBDateStart DateTime,
 NBDateEnd DateTime)


Declare	@PStartDate DateTime = @StartDate
Declare	@PEndDate DateTime = DateADD(D,1,@EndDate)
Declare @FirstDateOfYear DateTime
Declare	@LastDateOfYear DateTime

/* ---------------------- Join @AppStart table to FlatAppDetail to obtain ActualClosingDate & insert into table variable to filter out duplicates ---------------------- */
Insert Into @QueueTimes (AppID, AppDetailID, Name, QueueID, AppDetailSavePointID, ProductID, ProductShortName, DecisionStatusName, IsCurrentInQueueFL, CreationDate, AppMonth, AppYear, LoanTypeID, DecisionStatusID, QueueEntryDate, QueueEntryDay, CalendarDays, present) 
SELECT        View002.AppID, View002.AppDetailID, View003.Name, View002.QueueID, View001.AppDetailSavePointID, View001.ProductID,
                         View001.ProductShortName, View001.DecisionStatusName, View002.IsCurrentInQueueFL, CONVERT(varchar, View001.CreationDate, 1) 
                         AS CreationDate, MONTH(View001.CreationDate) AS AppMonth, YEAR(View001.CreationDate) AS AppYear, View004.LoanTypeID, 
                         View001.DecisionStatusID, View002.CreationDate AS QueueEntryDate, Convert(date, View002.CreationDate) AS QueueEntryDay,
						 (Cast(Round((((DateDiff(s, View002.CreationDate, @EndDate))) / 86400.000), 4) as numeric(8,3))) as CalendarDays, Convert(date, @EndDate) as present
FROM            View002 INNER JOIN
                         View003 ON View002.QueueID = View003.ID INNER JOIN
                         View001 ON View002.AppID = View001.AppID AND View002.AppDetailID = View001.AppDetailID INNER JOIN
                         View004 ON View001.AppID = View004.AppID AND View001.AppDetailID = View004.AppDetailID AND 
                         View001.AppDetailSavePointID = View004.AppDetailSavePointID
WHERE        (View001.AppDetailSavePointID = 0) AND 
			 (View002.IsCurrentInQueueFL = 1) AND 
			 (View002.QueueID IN (- 3, - 4, - 10, - 31, -14, -152, -206, -147))
ORDER BY View002.AppID, CreationDate DESC


/* Set the range in number of years (2) based upon @StartDate parameter that this query can determine the number of non-business days (NBD) and business days (BD) for a given date interval. */
SELECT @FirstDateOfYear = DATEADD(YYYY, DatePart(YYYY, @StartDate) - 1900, 0)
SELECT @LastDateOfYear =  DATEADD(YYYY, DatePart(YYYY, @StartDate) - 1900 + 2, 0)
																	
																			
/* Prepare calendar dates based upon the calendar year. */
;WITH CTE_WeekendCalendar AS (
SELECT 1 AS DayID,
@FirstDateOfYear AS FromDate,
DATENAME(dw, @FirstDateOfYear) AS Dayname
UNION ALL
SELECT cte.DayID + 1 AS DayID,
DATEADD(d, 1 ,cte.FromDate),
DATENAME(dw, DATEADD(d, 1 ,cte.FromDate)) AS Dayname
FROM CTE_WeekendCalendar CTE
WHERE DATEADD(d,1,cte.FromDate) < @LastDateOfYear)

/* Retrieve Non-Business Days setup in the system. */
Insert Into @NonBusinessDates
Select
Case When NBD.BeginDate Is Null Then Convert(date,
									 Convert(varchar(4), NBD.[Year]) +'-'+
									 Convert(varchar(2), NBD.[MonthNum]) + '-' +
									 Convert(varchar(2), NBD.[DayNum]))
							    Else Convert(Date, NBD.BeginDate)
End,																			
null																			
From  View005 NBD																			
Where NBD.IsActiveFL = 1																			
																			
Union																			
																			
/* Retrieve weekend dates based upon CTE_WeekendCalendar. */																			
SELECT FromDate, 																		
	   null																		
FROM CTE_WeekendCalendar																			
WHERE DayName In ('Sunday','Saturday')																			
OPTION (MaxRecursion 740)																			

/* Prepare calendar dates based upon the calendar year. */
;WITH CTE_PreviousBusinessDay AS (
SELECT 1 AS DayID,
Convert(date, @EndDate) AS FromDate,
DATENAME(dw, @EndDate) AS Dayname
UNION ALL
SELECT cte.DayID + 1 AS DayID,
DATEADD(d, -1 ,cte.FromDate),
DATENAME(dw, DATEADD(d, -1 ,cte.FromDate)) AS Dayname
FROM CTE_PreviousBusinessDay CTE
WHERE DATEADD(d,-1,cte.FromDate) in (select NBDateStart 
									 from @NonBusinessDates))

select @BusinessDaysP = (Select COUNT(*)											
						 From CTE_PreviousBusinessDay NBD)

/* ---------------------------------------------- Determine the Number of Non-Business Days for Application Status. -------------------------------------------------- */ 																																				
Update			ADS																
																			
Set				ADS.QueueEntry_PresentDateNBD =  															
					(Select COUNT(1)											
					 From @NonBusinessDates NBD											
					 Where NBD.NBDateStart Between Convert(Date, ADS.QueueEntryDate)											
											   and Convert(Date, @EndDate))
										
																			
From			@QueueTimes ADS																
																			
Where			ADS.QueueEntry_PresentDateNBD is Null;		

/* ----------------------------------------------  . -------------------------------------------------- */ 
Update			AG																
																			
Set				AG.Date = Dateadd(hour, -4, @EndDate),
								
				AG.[DLC RE Secured] = 
					(Select COUNT(1)											
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 1 and ADS.ProductID in (138,139,140,141,168,170,172)),

				AG.[DLC Quick Loans/ CC] = 
					(Select COUNT(1)											
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 1 and ADS.ProductID not in (138,139,140,141,168,170,172)),

				AG.[DLC Total Apps] = 
					(Select COUNT(1)											
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 1),

				AG.[DLC Oldest App] = 
					(Select min(ADS.QueueEntryDay)
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 1),
										
				AG.[DLC Oldest in Queue] = 
					(Select max((ADS.CalendarDays) - (ADS.QueueEntry_PresentDateNBD))											
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 1),

				AG.[SBLC RE Secured] = 
					(Select COUNT(1)											
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 2 and ADS.ProductID in (112,113,115,122)),

				AG.[SBLC Non_RE] = 
					(Select COUNT(1)											
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 2 and ADS.ProductID not in (112,113,115,122)),

				AG.[SBLC Total Apps] = 
					(Select COUNT(1)											
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 2),

				AG.[SBLC Oldest App] = 
					(Select min(ADS.QueueEntryDay)
					 From @QueueTimes ADS											
					 Where ADS.Loantypeid = 2),

				AG.[SBLC Oldest in Queue] =
					(Select max((ADS.CalendarDays) - (ADS.QueueEntry_PresentDateNBD))
					 From @QueueTimes ADS
					 Where ADS.Loantypeid = 2),

				AG.[DLC Total Apps Previous Day] =
					(Select count(*)
					 From View004 ad
					 left join View006 as AStart ON ad.AppID = AStart.AppID
					 left join (View007 AppDetailStatus_decision
								inner join View008 Status_decision on (AppDetailStatus_decision.StatusID = Status_decision.StatusID and
																	   Status_decision.StatusTypeID = 2 /* Decision */)
					) on (ad.AppID = AppDetailStatus_decision.AppID and
						  ad.AppDetailID = AppDetailStatus_decision.AppDetailID and
						  ad.AppDetailSavePointID = AppDetailStatus_decision.AppDetailSavePointID)
				Where ad.Loantypeid = 1 and
					  ad.AppDetailSavePointID = 0 and
					  Status_decision.Name not in ('Cancelled','Withdrawn') and
					  Convert(date, AStart.AppEntryCompletedDate) = DateAdd(d, -1 * @BusinessDaysP, Convert(date,@EndDate))),

				AG.[SBLC Total Apps Previous Day] =
					(Select count(*)
					 From View004 ad
					 left join View006 as AStart ON ad.AppID = AStart.AppID
					 left join (View007 AppDetailStatus_decision
								inner join View008 Status_decision on (AppDetailStatus_decision.StatusID = Status_decision.StatusID and
																				Status_decision.StatusTypeID = 2 /* Decision */)
					) on (ad.AppID = AppDetailStatus_decision.AppID and
						  ad.AppDetailID = AppDetailStatus_decision.AppDetailID and
						  ad.AppDetailSavePointID = AppDetailStatus_decision.AppDetailSavePointID)
				Where ad.Loantypeid = 2 and
					  ad.AppDetailSavePointID = 0 and
					  Status_decision.Name not in ('Cancelled','Withdrawn') and
					  Convert(date, AStart.AppEntryCompletedDate) = DateAdd(d, -1 * @BusinessDaysP, Convert(date,@EndDate))),
									   
				AG.[Previous Business Day] = DateAdd(d, -1 * @BusinessDaysP, Convert(date,@EndDate))

																			
From			@Aggregates AG																

SELECT [Date], 
[DLC RE Secured],
[DLC Quick Loans/ CC],
[DLC Total Apps],
[DLC Oldest App],	
[DLC Oldest in Queue],
[SBLC RE Secured],
[SBLC Non_RE],
[SBLC Total Apps],
[SBLC Oldest App],
[SBLC Oldest in Queue],
[DLC Total Apps Previous Day],
[SBLC Total Apps Previous Day],
[Previous Business Day]
from @Aggregates