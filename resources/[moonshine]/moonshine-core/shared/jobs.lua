--- Job-Definitionen. grades[0] ist immer der Einstiegsrang.
MS.Jobs = {
    unemployed = {
        label = 'Arbeitslos',
        whitelisted = false,
        grades = {
            [0] = { label = 'Arbeitslos', salary = 50 },
        },
    },

    police = {
        label = 'Los Santos Police Department',
        whitelisted = true,
        grades = {
            [0] = { label = 'Kadett',      salary = 800  },
            [1] = { label = 'Officer',     salary = 1200 },
            [2] = { label = 'Sergeant',    salary = 1600 },
            [3] = { label = 'Lieutenant',  salary = 2100 },
            [4] = { label = 'Chief',       salary = 2800 },
        },
    },

    ambulance = {
        label = 'Emergency Medical Services',
        whitelisted = true,
        grades = {
            [0] = { label = 'Praktikant',  salary = 750  },
            [1] = { label = 'Sanitaeter',  salary = 1150 },
            [2] = { label = 'Notarzt',     salary = 1700 },
            [3] = { label = 'Chefarzt',    salary = 2500 },
        },
    },

    mechanic = {
        label = 'Bennys Werkstatt',
        whitelisted = true,
        grades = {
            [0] = { label = 'Lehrling',    salary = 600  },
            [1] = { label = 'Mechaniker',  salary = 1000 },
            [2] = { label = 'Meister',     salary = 1500 },
            [3] = { label = 'Inhaber',     salary = 2200 },
        },
    },

    taxi = {
        label = 'Downtown Cab Co.',
        whitelisted = false,
        grades = {
            [0] = { label = 'Fahrer',      salary = 500 },
            [1] = { label = 'Disponent',   salary = 850 },
        },
    },

    trucker = {
        label = 'Spedition',
        whitelisted = false,
        grades = {
            [0] = { label = 'Fahrer',      salary = 550 },
        },
    },
}

MS.DefaultJob = 'unemployed'

--- Liefert die Job-Definition oder nil.
function MS.GetJob(name)
    return MS.Jobs[name]
end

--- Liefert einen validierten Job-Datensatz fuer den Spieler.
---@return table job { name, label, grade, gradeLabel, salary, whitelisted }
function MS.BuildJob(name, grade)
    local job = MS.Jobs[name]
    if not job then
        name  = MS.DefaultJob
        job   = MS.Jobs[name]
        grade = 0
    end

    grade = tonumber(grade) or 0
    local gradeData = job.grades[grade]
    if not gradeData then
        grade = 0
        gradeData = job.grades[0]
    end

    return {
        name        = name,
        label       = job.label,
        grade       = grade,
        gradeLabel  = gradeData.label,
        salary      = gradeData.salary,
        whitelisted = job.whitelisted or false,
    }
end
