# Current section: 7.7 Composition (shortened)

Replaces everything from `\subsection{Composition}` up to `\section{Verification}`. The listing is unchanged. The suffix explanation is shorter, the multi-action sentence is dropped (a detail nobody needs here), and the initial state is folded into the last paragraph.

```latex
\subsection{Composition}
\label{subsec:composition}

The five processes run in parallel and interact only through synchronised actions. Each synchronisation consists of halves suffixed by component (\texttt{\_d} dispatcher, \texttt{\_c} elevator, \texttt{\_im} intersection manager, \texttt{\_em} emergency switch), which \texttt{comm} fuses into a single action without a suffix.

\begin{lstlisting}
init allow({request, stops, visit, move, open, close,
            enterI, leaveI, done, emergency, reset},
  comm({stops_d | stops_c -> stops,
        visit_d | visit_c -> visit,
        enterI_c | enterI_im | enterI_em -> enterI,
        leaveI_c | leaveI_im -> leaveI,
        move_c | move_em -> move,
        request_d | request_em -> request},
    Dispatcher([]) || Elevator(A, 1, up) || Elevator(B, 1, up)
    || IntersectionManager(free) || EmergencySwitch(false)));
\end{lstlisting}

Since \texttt{allow} only admits the fused actions, a half can never occur on its own: an elevator cannot move without the emergency switch, nor enter I without both the intersection manager and the switch. Unlike hiding, the fused actions keep their name and data, so the requirements can refer to them directly. Initially, the pool is empty, both elevators are at level 1 heading up, I is free and no emergency is active.
```
