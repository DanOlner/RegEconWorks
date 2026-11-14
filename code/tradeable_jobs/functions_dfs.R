# Benchmark R1: Dornbusch, Fischer and Samuelson (1977), the Ricardian model with a continuum of goods
# z in [0, 1], two countries (Home, Foreign) with immobile labour L and Ls, and iceberg trade costs
# (a fraction g of each shipment arrives). Unit labour requirements a(z) at Home and as(z) abroad;
# A(z) = as(z) / a(z) is decreasing, so Home's comparative advantage is in low z. Cobb-Douglas spending
# with equal shares across goods. Foreign's wage is the numeraire, omega = w / ws.
#   Home exports z if w a(z) / g < ws as(z), i.e. A(z) > omega / g
#   Foreign exports z if A(z) < g omega
#   Goods in between are not traded: each country makes its own. The split between tradable and
#   non-tradable goods is endogenous.
# Trade balance (Home labour market): omega L = z_star (omega L - Tr) + z_bar (Ls + Tr), where z_bar
# and z_star are the shares of goods Home makes for Foreign and for itself, and Tr is a transfer from
# Home to Foreign (the DFS version of a fiscal shock).

dfs_solve <- function(a, as, g = 0.8, L = 1, Ls = 1, Tr = 0) {
  n <- length(a); A <- as / a
  balance <- function(omega) {
    home_exports <- A > omega / g                 # Home sells these to Foreign
    home_makes   <- A >= g * omega                # Home makes these for itself (exports plus non-traded)
    z_bar <- mean(home_exports); z_star <- mean(home_makes)
    omega * L - (z_star * (omega * L - Tr) + z_bar * (Ls + Tr))
  }
  omega <- uniroot(balance, c(1e-3, 1e3), tol = 1e-12)$root
  home_exports <- A > omega / g; home_makes <- A >= g * omega; foreign_exports <- !home_makes
  nontraded <- home_makes & !home_exports
  # Prices of each good in each country (Foreign wage = 1)
  pH <- ifelse(home_makes, omega * a, as / g)
  pF <- ifelse(home_exports, omega * a / g, as)
  tibble(omega = omega, home_export_share = mean(home_exports), nontraded_share = mean(nontraded),
         foreign_export_share = mean(foreign_exports),
         home_real_wage = exp(log(omega) - mean(log(pH))),   # w / P_H with equal Cobb-Douglas shares
         foreign_real_wage = exp(-mean(log(pF))))
}
