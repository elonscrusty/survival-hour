--!strict
-- Silos store earnings while the player is away (offline earnings). The reference's UI text
-- "Silos allow you to earn while you're away" and the "10 Permanent Silos" pass confirm the role;
-- that normal silos reset on rebirth is INFERRED from that pass. Numbers are DESIGN VALUES.

return {
	Max = 10,
	BaseCost = 5000, -- x egg costScale, x CostGrowth per silo already built
	CostGrowth = 2.2,
	MinutesPerSilo = 30, -- offline time covered by each silo (Epic upgrade adds more)
	OfflineRate = 0.5, -- fraction of the farm's steady cash rate earned while away
	MinAwaySeconds = 60, -- shorter absences pay nothing
}
