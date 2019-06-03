
/******************************************************************************************************************************
    Author:   RS
    Date:     08.02.2018
    Template: Training Exercise 001
    Purpose:  Simple exercise to gain some experience with Dynamic SQL along with Pivot.

                                                      Version History

    rev 1.0 - RS - 08.07.2018  -  Original Version Created.

******************************************************************************************************************************/ 

Set Transaction Isolation Level Read Uncommitted
Set NOCOUNT ON
Set Statistics Time ON

Declare @App Table (
AssociationName nvarchar(20),
Dense Int)

Insert Into @App
select distinct 'Applicant' + Convert(nvarchar(10), Dense_Rank() over (Partition by AppIndividual.AppID Order by AppIndividual.PartyID)) as AssociationName,
				Dense_Rank() over (Partition by AppIndividual.AppID Order by AppIndividual.PartyID) as Dense
							from View001 apapt
							inner join View002 Party on (apapt.PartyID = Party.PartyID)
							inner join View003 AppIndividual on (apapt.AppID = AppIndividual.AppID and
																				 apapt.PartyID = AppIndividual.PartyID)
							inner join View004 apt on (apapt.AppPartyTypeID = apt.AppPartyTypeID)
							inner join View005 Person on (AppIndividual.PartyID = Person.PartyID and
																   AppIndividual.BeginDate = Person.BeginDate)
order by Dense

Declare @colSQL NVARCHAR(MAX)

Select @colSQL = Coalesce(@colSQL + ',[' + App.AssociationName + ']', '[' + App.AssociationName + ']')
from @App App
Order By App.Dense


Declare @pvtSQL Nvarchar(Max)
Set @pvtSQL = N'
Select *
from
(select ad1.AppID, 
		ad1.AppDetailID, 
		''Applicant'' + Convert(nvarchar(10), Dense_Rank() over (Partition by ad1.AppID Order by lccb.PartyID)) as AssociationName,
		Score.TotalScore, Min(Score.TotalScore) over (Partition By ad1.AppDetailID) as Min_FICO,
		Count(lccb.PartyID) Over (Partition By ad1.AppDetailID) as Max_Borrowers
		from View006 ad1

		left join (select AppIndividual.AppID,
				   AppIndividual.PartyID,
				   apt.Name as AssociationName
				   from View001 apapt
				   inner join View002 Party on (apapt.PartyID = Party.PartyID)
				   inner join View003 AppIndividual on (apapt.AppID = AppIndividual.AppID and
													    apapt.PartyID = AppIndividual.PartyID)
				   inner join View004 apt on (apapt.AppPartyTypeID = apt.AppPartyTypeID)
				   inner join View005 Person on (AppIndividual.PartyID = Person.PartyID and
												 AppIndividual.BeginDate = Person.BeginDate)
					) lccb ON (ad1.AppID = lccb.AppID)
		left join (select AppID, PartyID, max(ScoreID) as ScoreID
				   from View007
				   where AppDetailSavePointID = 0
				   group by AppID, PartyID) b ON (ad1.AppID = b.AppID and 
												  lccb.PartyID = b.PartyID)
		left join v_RptScore_v001 as Score ON (b.ScoreID = Score.ScoreID)
		where ad1.loantypeid = 1 and 
			ad1.AppDetailSavepointid = 0 and 
			lccb.AssociationName not in (''Withdrawn'',''Co-Signer'')
) src
Pivot
(
	SUM(TotalScore)
	For AssociationName IN (' + @colSQL + ')
) pvt'

EXEC (@pvtSQL)

Set NOCOUNT OFF
Set Statistics Time OFF